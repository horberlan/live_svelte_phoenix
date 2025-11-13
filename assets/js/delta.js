// A heavily simplified but more correct implementation of Deltas
// based on the official quill-delta library.
// This is NOT a full implementation, but it is more robust
// than the previous one.

export class DeltaOp {
    static insert(text, attributes = null) {
        const op = { insert: text };
        if (attributes) op.attributes = attributes;
        return op;
    }

    static delete(length) {
        return { delete: length };
    }

    static retain(length, attributes = null) {
        const op = { retain: length };
        if (attributes) op.attributes = attributes;
        return op;
    }
}

export class Delta {
    constructor(ops = []) {
        this.ops = ops || [];
    }

    insert(text, attributes) {
        if (typeof text === 'string' && text.length === 0) {
            return this;
        }
        return this.push(DeltaOp.insert(text, attributes));
    }

    delete(length) {
        if (length <= 0) {
            return this;
        }
        return this.push(DeltaOp.delete(length));
    }

    retain(length, attributes) {
        if (length <= 0) {
            return this;
        }
        return this.push(DeltaOp.retain(length, attributes));
    }

    push(newOp) {
        let index = this.ops.length;
        let lastOp = this.ops[index - 1];
        newOp = { ...newOp };
        if (typeof lastOp === 'object') {
            if (typeof newOp.delete === 'number' && typeof lastOp.delete === 'number') {
                this.ops[index - 1] = { delete: lastOp.delete + newOp.delete };
                return this;
            }
            // Since we do not have any attributes, we can combine inserts
            // and retains with the same attributes.
            if (typeof lastOp.insert === 'string' && typeof newOp.insert === 'string' &&
                JSON.stringify(lastOp.attributes) === JSON.stringify(newOp.attributes)) {
                this.ops[index - 1] = { insert: lastOp.insert + newOp.insert };
                if (newOp.attributes) this.ops[index - 1].attributes = newOp.attributes;
                return this;
            }
            if (typeof lastOp.retain === 'number' && typeof newOp.retain === 'number' &&
                JSON.stringify(lastOp.attributes) === JSON.stringify(newOp.attributes)) {
                this.ops[index - 1] = { retain: lastOp.retain + newOp.retain };
                if (newOp.attributes) this.ops[index - 1].attributes = newOp.attributes;
                return this;
            }
        }
        this.ops.push(newOp);
        return this;
    }

    chop() {
        const lastOp = this.ops[this.ops.length - 1];
        if (lastOp && typeof lastOp.retain === 'number' && !lastOp.attributes) {
            this.ops.pop();
        }
        return this;
    }

    static fromTiptapTransaction(doc, tr) {
        const delta = new Delta();
        if (!tr.docChanged) {
            return delta;
        }

        let currentPos = 0;

        tr.steps.forEach(step => {
            const { from, to } = step;

            if (from > currentPos) {
                delta.retain(from - currentPos);
            }

            if (step.slice) {
                const content = step.slice.content;
                let textContent = '';
                let openMarks = [];

                content.forEach(node => {
                    if (node.isText) {
                        const nodeMarks = node.marks.map(mark => mark.toJSON());
                        
                        // Close marks that are not in the new node
                        const newOpenMarks = [];
                        openMarks.forEach(mark => {
                            if (!nodeMarks.some(m => JSON.stringify(m) === JSON.stringify(mark))) {
                                // mark is closed
                            } else {
                                newOpenMarks.push(mark);
                            }
                        });
                        openMarks = newOpenMarks;

                        // Open marks that are new
                        nodeMarks.forEach(mark => {
                            if (!openMarks.some(m => JSON.stringify(m) === JSON.stringify(mark))) {
                                openMarks.push(mark);
                            }
                        });

                        textContent += node.text;
                    }
                });

                if (to > from) {
                    delta.delete(to - from);
                }

                if (textContent) {
                    const attributes = {};
                    openMarks.forEach(mark => {
                        if (mark.type === 'bold') attributes.bold = true;
                        if (mark.type === 'italic') attributes.italic = true;
                    });
                    delta.insert(textContent, Object.keys(attributes).length > 0 ? attributes : null);
                }

            } else if (to > from) {
                delta.delete(to - from);
            }
            currentPos = to;
        });

        const docSize = doc.content.size;
        if (currentPos < docSize) {
            delta.retain(docSize - currentPos);
        }

        return delta.chop();
    }

    static applyToTiptap(editor, delta) {
        if (!delta || !delta.ops || delta.ops.length === 0) return;

        const tr = editor.state.tr;
        tr.setMeta('isRemote', true);
        tr.setMeta('addToHistory', false);

        let index = 1; // TipTap uses 1-based indexing

        delta.ops.forEach((op) => {
            if (op.retain !== undefined) {
                if (op.attributes) {
                    const from = index;
                    const to = index + op.retain;
                    const docSize = tr.doc.content.size;

                    if (from > to || from > docSize) {
                        // Invalid range, skip.
                    } else {
                        const marks = [];
                        Object.entries(op.attributes).forEach(([key, value]) => {
                            const markType = editor.schema.marks[key];
                            if (markType && value) {
                                marks.push(markType.create());
                            }
                        });
                        tr.addMark(from, Math.min(to, docSize), marks);
                    }
                }
                index += op.retain;
            } else if (op.insert !== undefined) {
                const text = op.insert;
                if (text) {
                    const marks = [];
                    if (op.attributes) {
                        Object.entries(op.attributes).forEach(([key, value]) => {
                            const markType = editor.schema.marks[key];
                            if (markType && value) {
                                marks.push(markType.create());
                            }
                        });
                    }
                    // Clamp insert position to be within the current document size
                    const insertPos = Math.min(index, tr.doc.content.size);
                    tr.insertText(text, insertPos, marks);
                    index += text.length;
                }
            } else if (op.delete !== undefined) {
                const from = index;
                const to = index + op.delete;
                const docSize = tr.doc.content.size;
                
                if (from > to || from > docSize) {
                    // Invalid range, skip
                } else {
                    tr.delete(from, Math.min(to, docSize));
                }
            }
        });

        if (tr.docChanged) {
            editor.view.dispatch(tr);
        }
    }

    static transformAttributes(a, b, priority) {
        if (typeof a !== 'object') a = {};
        if (typeof b !== 'object') b = {};
        if (typeof a !== 'object' || typeof b !== 'object') return undefined;
        if (!priority) { // b has priority
            return b;
        }
        const attributes = {};
        for (const key in b) {
            if (b[key] !== null) attributes[key] = b[key];
        }
        for (const key in a) {
            if (a[key] !== null && b[key] === undefined) {
                attributes[key] = a[key];
            }
        }
        return Object.keys(attributes).length > 0 ? attributes : undefined;
    }

    static transform(deltaA, deltaB, priority = false) {
        deltaA = new Delta(deltaA.ops || deltaA);
        deltaB = new Delta(deltaB.ops || deltaB);
        const delta = new Delta();
        const a = new DeltaIterator(deltaA.ops);
        const b = new DeltaIterator(deltaB.ops);
        while (a.hasNext() || b.hasNext()) {
            if (a.peekType() === 'insert' && (priority || b.peekType() !== 'insert')) {
                delta.retain(a.peekLength());
                a.next();
            } else if (b.peekType() === 'insert') {
                delta.insert(b.peek().insert, b.peek().attributes);
                b.next();
            } else {
                const length = Math.min(a.peekLength(), b.peekLength());
                const aOp = a.next(length);
                const bOp = b.next(length);
                if (aOp.delete) {
                    // b also deletes, or keeps
                    // noop
                } else if (bOp.delete) {
                    delta.delete(length);
                } else { // both are retains
                    const attributes = Delta.transformAttributes(aOp.attributes, bOp.attributes, priority);
                    delta.retain(length, attributes);
                }
            }
        }
        return delta.chop();
    }

    static compose(deltaA, deltaB) {
        const a = new DeltaIterator(deltaA.ops);
        const b = new DeltaIterator(deltaB.ops);
        const delta = new Delta();
        while (a.hasNext() || b.hasNext()) {
            if (b.peekType() === 'insert') {
                delta.insert(b.peek().insert, b.peek().attributes);
                b.next();
            } else if (a.peekType() === 'delete') {
                delta.delete(a.peekLength());
                a.next();
            } else {
                const length = Math.min(a.peekLength(), b.peekLength());
                const aOp = a.next(length);
                const bOp = b.next(length);
                if (typeof bOp.retain === 'number') {
                    const newOp = { retain: length };
                    if (aOp.attributes) newOp.attributes = aOp.attributes;
                    if (bOp.attributes) newOp.attributes = bOp.attributes;
                    delta.push(newOp);
                } else if (typeof bOp.delete === 'number') {
                    delta.delete(length);
                } else if (typeof aOp.retain === 'number') {
                    delta.insert(bOp.insert, bOp.attributes);
                }
            }
        }
        return delta.chop();
    }

    static transformIndex(index, delta, priority = false) {
        let newIndex = index;
        let cursor = 0;
        (delta.ops || delta).forEach(op => {
            if (op.retain) {
                cursor += op.retain;
            } else if (op.insert) {
                if (cursor < newIndex || (cursor === newIndex && !priority)) {
                    newIndex += op.insert.length;
                }
                cursor += op.insert.length;
            } else if (op.delete) {
                if (cursor < newIndex) {
                    newIndex -= Math.min(op.delete, newIndex - cursor);
                }
            }
        });
        return newIndex;
    }

    toJSON() {
        return this.ops;
    }
}

class DeltaIterator {
    constructor(ops) {
        this.ops = ops;
        this.index = 0;
        this.offset = 0;
    }

    hasNext() {
        return this.peek() != null;
    }

    peek() {
        return this.ops[this.index];
    }

    peekLength() {
        if (this.ops[this.index]) {
            if (typeof this.ops[this.index].delete === 'number') {
                return this.ops[this.index].delete;
            }
            if (typeof this.ops[this.index].retain === 'number') {
                return this.ops[this.index].retain;
            }
            if (typeof this.ops[this.index].insert === 'string') {
                return this.ops[this.index].insert.length;
            }
        }
        return 0;
    }

    peekType() {
        if (this.ops[this.index]) {
            if (typeof this.ops[this.index].delete === 'number') {
                return 'delete';
            }
            if (typeof this.ops[this.index].retain === 'number') {
                return 'retain';
            }
            return 'insert';
        }
        return 'retain';
    }

    next(length) {
        const nextOp = this.ops[this.index];
        if (nextOp) {
            const offset = this.offset;
            const opLength = this.peekLength();
            if (length >= opLength - offset) {
                length = opLength - offset;
                this.index += 1;
                this.offset = 0;
            } else {
                this.offset += length;
            }
            if (typeof nextOp.delete === 'number') {
                return { delete: length };
            }
            const op = {};
            if (nextOp.attributes) {
                op.attributes = nextOp.attributes;
            }
            if (typeof nextOp.retain === 'number') {
                op.retain = length;
            } else if (typeof nextOp.insert === 'string') {
                op.insert = nextOp.insert.substr(offset, length);
            }
            return op;
        } else {
            return { retain: Infinity };
        }
    }
}
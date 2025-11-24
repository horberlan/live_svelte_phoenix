import Delta from 'quill-delta';

// Polyfill toJSON if it doesn't exist (Quill Delta v4+ might not have it)
if (!Delta.prototype.toJSON) {
    Delta.prototype.toJSON = function () {
        return this.ops;
    };
}

// Add static methods to match the previous custom API

// Transform deltaB against deltaA
Delta.transform = function (deltaA, deltaB, priority = false) {
    const a = new Delta(deltaA);
    const b = new Delta(deltaB);
    return a.transform(b, priority);
};

// Transform index against delta
Delta.transformIndex = function (index, delta, priority = false) {
    const d = new Delta(delta);
    return d.transformPosition(index, priority);
};

Delta.fromTiptapTransaction = function (doc, tr) {
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
};

Delta.applyToTiptap = function (editor, delta) {
    const tr = editor.state.tr;
    if (!delta || !delta.ops || delta.ops.length === 0) {
        return tr;
    }

    tr.setMeta('isRemote', true);
    tr.setMeta('addToHistory', false);

    let index = 0;


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

    return tr;
};

export { Delta };
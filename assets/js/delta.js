
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
        this.ops = ops;
    }

    /**
     * Computes the difference between two text strings as a Delta
     * This is a proper diff implementation following Delta best practices
     * @param {string} oldText - The original text
     * @param {string} newText - The new text
     * @returns {Delta} A delta representing the changes
     */
    static diff(oldText, newText) {
        const ops = [];

        // Find common prefix
        let prefixLength = 0;
        while (
            prefixLength < oldText.length &&
            prefixLength < newText.length &&
            oldText[prefixLength] === newText[prefixLength]
        ) {
            prefixLength++;
        }

        // Find common suffix
        let suffixLength = 0;
        while (
            suffixLength < oldText.length - prefixLength &&
            suffixLength < newText.length - prefixLength &&
            oldText[oldText.length - 1 - suffixLength] === newText[newText.length - 1 - suffixLength]
        ) {
            suffixLength++;
        }

        // Build Delta operations
        if (prefixLength > 0) {
            ops.push(DeltaOp.retain(prefixLength));
        }

        const deletedLength = oldText.length - prefixLength - suffixLength;
        if (deletedLength > 0) {
            ops.push(DeltaOp.delete(deletedLength));
        }

        const insertedText = newText.substring(prefixLength, newText.length - suffixLength);
        if (insertedText.length > 0) {
            ops.push(DeltaOp.insert(insertedText));
        }

        return new Delta(ops);
    }

    static fromTiptapTransaction(tr) {
        const ops = [];

        // Convert both documents to complete deltas with formatting
        const oldDelta = Delta.fromTiptapDoc(tr.before);
        const newDelta = Delta.fromTiptapDoc(tr.doc);

        // Calculate the difference between the two deltas
        return Delta.diff(oldDelta, newDelta);
    }

    /**
     * Calculates the difference between two deltas (complete documents)
     * @param {Delta} oldDelta - Delta of the old document
     * @param {Delta} newDelta - Delta of the new document
     * @returns {Delta} Delta representing the changes
     */
    static diff(oldDelta, newDelta) {
        const ops = [];
        let oldIndex = 0;
        let newIndex = 0;

        const oldOps = oldDelta.ops || [];
        const newOps = newDelta.ops || [];

        while (oldIndex < oldOps.length || newIndex < newOps.length) {
            const oldOp = oldOps[oldIndex];
            const newOp = newOps[newIndex];

            if (!oldOp) {
                if (newOp.insert) {
                    ops.push(newOp);
                }
                newIndex++;
                continue;
            }

            if (!newOp) {
                if (oldOp.insert) {
                    const length = typeof oldOp.insert === 'string' ? oldOp.insert.length : 1;
                    ops.push(DeltaOp.delete(length));
                }
                oldIndex++;
                continue;
            }

            if (oldOp.insert && newOp.insert) {
                const oldText = typeof oldOp.insert === 'string' ? oldOp.insert : '';
                const newText = typeof newOp.insert === 'string' ? newOp.insert : '';

                const sameText = oldText === newText;
                const sameAttrs = JSON.stringify(oldOp.attributes || {}) === JSON.stringify(newOp.attributes || {});

                if (sameText && sameAttrs) {
                    ops.push(DeltaOp.retain(oldText.length, oldOp.attributes));
                    oldIndex++;
                    newIndex++;
                } else if (sameText && !sameAttrs) {
                    ops.push(DeltaOp.retain(oldText.length, newOp.attributes));
                    oldIndex++;
                    newIndex++;
                } else {
                    if (oldText.length > 0) {
                        ops.push(DeltaOp.delete(oldText.length));
                    }
                    if (newText.length > 0) {
                        ops.push(DeltaOp.insert(newText, newOp.attributes));
                    }
                    oldIndex++;
                    newIndex++;
                }
            }
        }

        return new Delta(ops);
    }

    static marksToAttributes(marks) {
        if (!marks || marks.length === 0) return null;

        const attributes = {};
        marks.forEach((mark) => {
            switch (mark.type.name) {
                case 'bold':
                    attributes.bold = true;
                    break;
                case 'italic':
                    attributes.italic = true;
                    break;
                case 'underline':
                    attributes.underline = true;
                    break;
                case 'strike':
                    attributes.strike = true;
                    break;
                case 'code':
                    attributes.code = true;
                    break;
                case 'link':
                    attributes.link = mark.attrs.href;
                    break;
                case 'textStyle':
                    if (mark.attrs.color) attributes.color = mark.attrs.color;
                    break;
                default:
                    break;
            }
        });

        return Object.keys(attributes).length > 0 ? attributes : null;
    }

    static fromTiptapDoc(doc) {
        const ops = [];
        let isFirstNode = true;

        doc.descendants((node, pos, parent) => {
            if (node.isText) {
                // Text with formatting marks (bold, italic, etc)
                const attributes = Delta.marksToAttributes(node.marks);

                // Add block attributes from parent node
                const blockAttributes = Delta.nodeToBlockAttributes(parent);
                const combinedAttributes = { ...attributes, ...blockAttributes };

                ops.push(DeltaOp.insert(node.text, Object.keys(combinedAttributes).length > 0 ? combinedAttributes : null));
            } else if (node.type.name === 'hardBreak') {
                ops.push(DeltaOp.insert('\n'));
            } else if (node.isBlock && !isFirstNode) {
                // Add line break between blocks (paragraphs, headings, etc)
                const blockAttributes = Delta.nodeToBlockAttributes(node);
                ops.push(DeltaOp.insert('\n', Object.keys(blockAttributes).length > 0 ? blockAttributes : null));
            }

            if (node.isBlock) {
                isFirstNode = false;
            }
        });

        return new Delta(ops);
    }

    /**
     * Converts TipTap node attributes to Delta block attributes
     * @param {Node} node - TipTap node
     * @returns {Object} Block attributes
     */
    static nodeToBlockAttributes(node) {
        if (!node || !node.type) return {};

        const attributes = {};

        switch (node.type.name) {
            case 'heading':
                attributes.header = node.attrs.level;
                break;
            case 'bulletList':
                attributes.list = 'bullet';
                break;
            case 'orderedList':
                attributes.list = 'ordered';
                break;
            case 'listItem':
                // Inherit from parent
                if (node.parent && node.parent.type.name === 'bulletList') {
                    attributes.list = 'bullet';
                } else if (node.parent && node.parent.type.name === 'orderedList') {
                    attributes.list = 'ordered';
                }
                break;
            case 'blockquote':
                attributes.blockquote = true;
                break;
            case 'codeBlock':
                attributes.codeBlock = true;
                if (node.attrs.language) {
                    attributes.language = node.attrs.language;
                }
                break;
            default:
                break;
        }

        return attributes;
    }

    /**
     * Transforms a cursor position through a Delta operation
     * This is the proper way to handle cursor preservation in OT
     * @param {number} index - The cursor position to transform
     * @param {Delta} delta - The delta operation to transform through
     * @param {boolean} priority - Whether this cursor has priority (for tie-breaking)
     * @returns {number} The transformed cursor position
     */
    static transformIndex(index, delta, priority = false) {
        let transformedIndex = index;
        let currentIndex = 0;

        for (const op of delta.ops) {
            if (op.retain !== undefined) {
                currentIndex += op.retain;
            } else if (op.insert !== undefined) {
                const text = typeof op.insert === 'string' ? op.insert : '';
                const insertLength = text.length;

                if (currentIndex < index || (currentIndex === index && priority)) {
                    transformedIndex += insertLength;
                }
                currentIndex += insertLength;
            } else if (op.delete !== undefined) {
                const deleteLength = op.delete;
                const deleteEnd = currentIndex + deleteLength;

                if (deleteEnd <= index) {
                    transformedIndex -= deleteLength;
                } else if (currentIndex < index) {
                    transformedIndex -= (index - currentIndex);
                    transformedIndex = currentIndex;
                }
            }
        }

        return Math.max(0, transformedIndex);
    }

    /**
     * Composes two deltas into a single delta
     * This is used to combine multiple operations
     * @param {Delta} a - First delta
     * @param {Delta} b - Second delta to apply after first
     * @returns {Delta} Composed delta
     */
    static compose(a, b) {
        const ops = [];
        let aIndex = 0;
        let bIndex = 0;

        while (aIndex < a.ops.length || bIndex < b.ops.length) {
            const aOp = a.ops[aIndex];
            const bOp = b.ops[bIndex];

            if (!bOp) {
                ops.push(aOp);
                aIndex++;
            } else if (!aOp) {
                ops.push(bOp);
                bIndex++;
            } else if (bOp.insert !== undefined) {
                ops.push(bOp);
                bIndex++;
            } else if (aOp.delete !== undefined) {
                ops.push(aOp);
                aIndex++;
            } else if (bOp.delete !== undefined) {
                ops.push(bOp);
                bIndex++;
            } else {
                // Both are retains
                const aRetain = aOp.retain || 0;
                const bRetain = bOp.retain || 0;

                if (aRetain < bRetain) {
                    ops.push({ retain: aRetain, ...bOp.attributes && { attributes: bOp.attributes } });
                    aIndex++;
                    b.ops[bIndex] = { retain: bRetain - aRetain, ...bOp.attributes && { attributes: bOp.attributes } };
                } else if (aRetain > bRetain) {
                    ops.push({ retain: bRetain, ...bOp.attributes && { attributes: bOp.attributes } });
                    bIndex++;
                    a.ops[aIndex] = { retain: aRetain - bRetain, ...aOp.attributes && { attributes: aOp.attributes } };
                } else {
                    ops.push({ retain: aRetain, ...bOp.attributes && { attributes: bOp.attributes } });
                    aIndex++;
                    bIndex++;
                }
            }
        }

        return new Delta(ops);
    }

    static applyToTiptap(editor, delta) {
        if (!delta || !delta.ops || delta.ops.length === 0) return;

        const tr = editor.state.tr;
        tr.setMeta('isRemote', true);
        tr.setMeta('addToHistory', false);

        let index = 1; // TipTap uses 1-based indexing

        delta.ops.forEach((op) => {
            if (op.retain !== undefined) {
                const start = index;
                const end = index + op.retain;

                if (op.attributes) {
                    // Apply formatting marks (bold, italic, etc)
                    Object.entries(op.attributes).forEach(([key, value]) => {
                        if (key === 'header' || key === 'list' || key === 'blockquote' || key === 'codeBlock') {
                            // Block attributes are applied to the node, not as marks
                            return;
                        }

                        const markType = editor.schema.marks[key];
                        if (!markType) return;

                        if (value === null || value === false) {
                            tr.removeMark(start, end, markType);
                        } else {
                            const attrs = typeof value === 'object' ? value : undefined;
                            const mark = markType.create(attrs);
                            tr.addMark(start, end, mark);
                        }
                    });
                }

                index += op.retain;
            } else if (op.insert !== undefined) {
                const text = typeof op.insert === 'string' ? op.insert : '';

                if (text) {
                    // Check if it's a line break with block attributes
                    if (text === '\n' && op.attributes) {
                        const blockAttrs = Delta.attributesToBlockType(op.attributes);

                        if (blockAttrs.type) {
                            // Insert a new block with the correct type
                            const nodeType = editor.schema.nodes[blockAttrs.type];
                            if (nodeType) {
                                const node = nodeType.create(blockAttrs.attrs);
                                tr.insert(index, node);
                                index += node.nodeSize;
                            } else {
                                tr.insertText(text, index);
                                index += text.length;
                            }
                        } else {
                            tr.insertText(text, index);
                            index += text.length;
                        }
                    } else {
                        // Insert normal text
                        tr.insertText(text, index);

                        // Apply formatting marks
                        if (op.attributes) {
                            Object.entries(op.attributes).forEach(([key, value]) => {
                                if (key === 'header' || key === 'list' || key === 'blockquote' || key === 'codeBlock') {
                                    return;
                                }

                                const markType = editor.schema.marks[key];
                                if (markType && value !== null && value !== false) {
                                    const attrs = typeof value === 'object' ? value : undefined;
                                    const mark = markType.create(attrs);
                                    tr.addMark(index, index + text.length, mark);
                                }
                            });
                        }

                        index += text.length;
                    }
                }
            } else if (op.delete !== undefined) {
                tr.delete(index, index + op.delete);
            }
        });

        editor.view.dispatch(tr);
    }

    /**
     * Converts Delta attributes to TipTap block type
     * @param {Object} attributes - Delta attributes
     * @returns {Object} Block type and attributes
     */
    static attributesToBlockType(attributes) {
        if (!attributes) return { type: null, attrs: {} };

        if (attributes.header) {
            return { type: 'heading', attrs: { level: attributes.header } };
        }

        if (attributes.list === 'bullet') {
            return { type: 'bulletList', attrs: {} };
        }

        if (attributes.list === 'ordered') {
            return { type: 'orderedList', attrs: {} };
        }

        if (attributes.blockquote) {
            return { type: 'blockquote', attrs: {} };
        }

        if (attributes.codeBlock) {
            return {
                type: 'codeBlock',
                attrs: attributes.language ? { language: attributes.language } : {}
            };
        }

        return { type: null, attrs: {} };
    }

    toJSON() {
        return this.ops;
    }
}

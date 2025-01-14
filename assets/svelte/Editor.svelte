<script>
    import { onMount, onDestroy } from "svelte";
    import { Editor } from "@tiptap/core";
    import StarterKit from "@tiptap/starter-kit";
    import BubbleMenu from "@tiptap/extension-bubble-menu";
    import FloatingMenu from "@tiptap/extension-floating-menu";

    let element;
    let editor;
    let bubbleMenu;
    let floatingMenu;

    let bubbleMenuItems = [
        {
            label: "H1",
            active: () => ("heading", { level: 1 }),
            command: () =>
                editor.chain().focus().toggleHeading({ level: 1 }).run(),
        },
        {
            label: "H2",
            active: () => ("heading", { level: 2 }),

            command: () =>
                editor.chain().focus().toggleHeading({ level: 2 }).run(),
        },
        {
            label: "H3",
            active: () => ("heading", { level: 3 }),

            command: () =>
                editor.chain().focus().toggleHeading({ level: 3 }).run(),
        },
        {
            label: "P",
            active: () => "paragraph",

            command: () => editor.chain().focus().setParagraph().run(),
        },
        {
            label: "Bold",
            active: () => "bold",

            command: () => editor.chain().focus().toggleBold().run(),
        },
        {
            label: "Italic",
            active: () => "italic",
            command: () => editor.chain().focus().toggleItalic().run(),
        },
    ];

    onMount(() => {
        editor = new Editor({
            element: element,
            extensions: [
                StarterKit,
                BubbleMenu.configure({
                    element: bubbleMenu,
                }),
                FloatingMenu.configure({
                    element: floatingMenu,
                }),
            ],
            editorProps: {
                attributes: {
                    class: "prose prose-sm sm:prose-base lg:prose-lg xl:prose-2xl m-5 focus:outline-none bg-white shadow-md p-4 rounded-lg",
                },
            },
            content: "<p>Hello World!</p>",
            onTransaction: () => {
                editor = editor;
            },
        });
    });

    onDestroy(() => {
        if (editor) {
            editor.destroy();
        }
    });
</script>

<div
    class="bubble-menu flex gap-2 bg-gray-100 p-2 rounded-lg shadow-sm"
    bind:this={bubbleMenu}
>
    {#if editor}
        {#each bubbleMenuItems as item}
            <button
                on:click={item.command}
                class:active={editor.isActive(item.active())}
                class="bg-gray-200 px-3 py-1 rounded-md hover:bg-gray-300 focus:outline-none"
            >
                {item.label}
            </button>
        {/each}
    {/if}
</div>

<div bind:this={element} />

<style>
    button.active {
        background: black;
        color: white;
    }
</style>

import { Extension } from '@tiptap/core';
import { Plugin, PluginKey } from '@tiptap/pm/state';
import { Decoration, DecorationSet } from '@tiptap/pm/view';



export const CollaborationCursor = Extension.create({



  name: 'collaborationCursor',







  addOptions() {



    return {



      client: null,



      onUpdate: () => {},



      themeColors: [



        "hsl(249 63% 57%)",



        "hsl(338 83% 64%)",



        "hsl(174 56% 51%)",



        "hsl(45 8% 25%)",



        "hsl(198 82% 61%)",



        "hsl(152 56% 51%)",



        "hsl(43 89% 57%)",



        "hsl(0 87% 71%)",



      ],



    };



  },







  addStorage() {



    return {



      collaborators: new Map(),



    };



  },







  addProseMirrorPlugins() {



    const extension = this;







    function userColor(userId) {



      const userNum = parseInt(userId.replace(/[^0-9]/g, ''), 10) || 0;



      return extension.options.themeColors[userNum % extension.options.themeColors.length];



    }







    return [



      new Plugin({



        key: new PluginKey('collaborationCursor'),



        state: {



          init: () => {



            return {



              decorations: DecorationSet.empty,



            };



          },



          apply: (tr, value, oldState, newState) => {



            const collaborators = extension.options.client?.collaborators || new Map();



            const decorations = [];







            collaborators.forEach((collab, id) => {



              if (collab.cursor_position && collab.name) {



                const color = collab.color || userColor(id);



                collab.color = color;







                const cursorDecoration = Decoration.widget(



                  collab.cursor_position.from,



                  () => {



                    const cursorEl = document.createElement('span');



                    cursorEl.classList.add('collaboration-cursor');



                    cursorEl.style.borderColor = color;







                    const nameEl = document.createElement('span');



                    nameEl.classList.add('collaboration-cursor-name');



                    nameEl.style.backgroundColor = color;



                    nameEl.textContent = collab.name;







                    cursorEl.appendChild(nameEl);



                    return cursorEl;



                  },



                  {



                    key: id,



                    side: -1,



                  }



                );



                decorations.push(cursorDecoration);



              }



            });







            return {



              decorations: DecorationSet.create(newState.doc, decorations),



            };



          },



        },



        props: {



          decorations(state) {



            return this.getState(state).decorations;



          },



        },



      }),



    ];



  },



});

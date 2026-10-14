import {defineConfig} from 'tsup';
export default defineConfig({entry:['reference/src/index.ts','reference/src/browser.ts'],format:['esm','cjs'],dts:true,clean:true,sourcemap:true,target:'es2020'});

import * as Components from './components';
// Webpack will automatically convert this to window if your project is targeted for web (default). 
// Read more here: https://webpack.js.org/configuration/node/.
declare var global: any;
global.Components = Components;
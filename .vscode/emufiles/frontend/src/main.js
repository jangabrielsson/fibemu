import 'bootstrap/dist/css/bootstrap.css';
import 'bootstrap/dist/js/bootstrap.js';
import { createApp } from 'vue';
import axios from 'axios';
import { useAccordion } from "vue3-rich-accordion";
import "vue3-rich-accordion/accordion-library-styles.css";

import App from './App.vue';
import QuickAppUI from './components/QuickAppUI.vue';
import QuickApp from './components/QuickApp.vue';
import MenuBar from './components/MenuBar.vue';
import QuickAppPanel from './components/QuickAppPanel.vue';

const app = createApp(App);
app.use(useAccordion);

app.component('quick-app-ui', QuickAppUI);
app.component('quick-app', QuickApp);
app.component('quick-app-panel', QuickAppPanel);
app.component('menu-bar', MenuBar);

app.mount('#app');

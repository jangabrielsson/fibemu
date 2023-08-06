import 'bootstrap/dist/css/bootstrap.css';
import 'bootstrap/dist/js/bootstrap.js';
import { createApp } from 'vue';
import { createRouter, createWebHistory } from 'vue-router';
import { useAccordion } from "vue3-rich-accordion";
import "vue3-rich-accordion/accordion-library-styles.css";

import App from './App.vue';
import QuickAppUI from './components/QuickAppUI.vue';
import QuickApp from './components/QuickApp.vue';
import MenuBar from './components/MenuBar.vue';
import QuickAppPanel from './components/QuickAppPanel.vue';
import AboutPanel from './components/AboutPanel.vue';
import ConfigPanel from './components/ConfigPanel.vue';
import EventPanel from './components/EventPanel.vue';
import GlobalVarPanel from './components/GlobalVarPanel.vue';

const router = createRouter({
    history: createWebHistory(),
    routes: [
        { path: '/', component: QuickAppPanel },
        { path: '/frontend/', component: QuickAppPanel },
        { path: '/frontend/index.html', component: QuickAppPanel },
        { path: '/frontend/home', component: QuickAppPanel },
        { path: '/frontend/events', component: EventPanel },
        { path: '/frontend/globals', component: GlobalVarPanel },
        { path: '/frontend/config', component: ConfigPanel },
        { path: '/frontend/about', component: AboutPanel },
    ],
});

const app = createApp(App);
app.use(useAccordion);
app.use(router)

app.component('quick-app-ui', QuickAppUI);
app.component('quick-app', QuickApp);
app.component('quick-app-panel', QuickAppPanel);
app.component('menu-bar', MenuBar);
app.component('about-panel', AboutPanel);
app.component('config-panel', ConfigPanel);
app.component('event-panel', EventPanel);
app.component('globalvar-panel', GlobalVarPanel);

app.mount('#app');

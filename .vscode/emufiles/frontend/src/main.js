import 'bootstrap/dist/css/bootstrap.css';
import { createApp } from 'vue';
import axios from 'axios';

import App from './App.vue';
import QuickApp from './components/QuickApp.vue';

const app = createApp(App);

app.component('quick-app', QuickApp);

app.mount('#app');

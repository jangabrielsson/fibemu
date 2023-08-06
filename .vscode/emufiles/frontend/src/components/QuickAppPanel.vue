<template>
    <section>
        <!-- <AccordionList v-model:state="state" open-multiple-items> -->
        <AccordionList open-multiple-items>
            <AccordionItem v-for="(qa,i) in quickApps" :key="qa" :id="qa.id" id="mId1" :default-opened="i === 0">
                <template #summary>QA: '{{ qa.name }}' ({{ qa.id }})</template>
                <template #icon>+</template>
                <quick-app :key="qa.id" :id="qa.id"></quick-app>
            </AccordionItem>
        </AccordionList>
    </section>
</template>
  
<script>

import QuickApp from './QuickApp.vue';

export default {
    components: {
        'quick-app': QuickApp,
    },
    data() {
        return {
            quickApps: [],
        };
    },
    methods: {
    },
    mounted() {
        fetch("http://localhost:5004/emu/qa", {
            method: "GET",
            headers: {
                "Content-Type": "application/json",
            },
        })
            .then((response) => response.json())
            .then((data) => {
                console.log("Got quickApps " + JSON.stringify(data));
                data.sort((a, b) => a.id < b.id ? -1 : (a.id > b.id ? 1 : 0));
                this.quickApps = data;
            });
    },
};
</script>
<template>
    <section>
        <!-- <AccordionList v-model:state="state" open-multiple-items> -->
        <AccordionList v-model:state="state" open-multiple-items>
            <AccordionItem v-for="(qa,i) in quickApps" :key="qa" :id="qa.id" id="mId1" :default-opened="i === 0">
                <template #summary>QA: '{{ qa.name }}' ({{ qa.id }})</template>
                <template #icon>+</template>
                <quick-app :key="qa.id" :id="qa.id" :state="state" :start="i === 0"></quick-app>
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
            state: {},
        };
    },
    methods: {
    },
    mounted() {
        fetch(this.$store.state.backend+"/emu/qa", {
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
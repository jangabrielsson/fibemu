<template>
    <section>
        <!-- <AccordionList v-model:state="state" open-multiple-items> -->
        <AccordionList v-model:state="state" open-multiple-items>
            <AccordionItem v-for="(qa,i) in quickApps" :key="qa" :id="qa.id" id="mId1" :default-opened="i === 0">
                <template #summary>{{qa.pad}}: {{ qa.id }}: '{{ qa.name }}'</template>
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
                for (let qa of data) {
                    console.log("Got quickApp " + JSON.stringify(qa));
                    if (!qa.parent || qa.parent === 0) {
                        qa.pid = qa.id + "/";
                        qa.pad = "QA"
                    } else {
                        qa.pid = qa.parent + "/" + qa.id;
                        qa.pad = "Child QA"
                    }
                };
                data.sort((a, b) => a.pid < b.pid ? -1 : (a.pid > b.pid ? 1 : 0));
                this.quickApps = data;
            });
    },
};
</script>
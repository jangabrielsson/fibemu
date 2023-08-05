<template>
    <section>
        <AccordionList v-model:state="state" open-multiple-items=true>
            <AccordionItem v-for="(qa,i) in quickApps" :key="qa.id" :id="qa.id" id="mId1" :default-opened="i === 0">
                <template #summary>QA: '{{ qa.name }}' ({{ qa.id }})</template>
                <template #icon>+</template>
                <quick-app :key="qa.id" :id="qa.id"></quick-app>
            </AccordionItem>
        </AccordionList>
    </section>
</template>
  
<script>
export default {
    data() {
        return {
            quickApps: [],
        };
    },
    methods: {
    },
    mounted() {
        fetch("http://192.168.1.129:5004/emu/qa", {
            method: "GET",
            headers: {
                "Content-Type": "application/json",
            },
        })
            .then((response) => response.json())
            .then((data) => {
                // console.log("Got quickApps " + JSON.stringify(data));
                data.sort((a, b) => a.id < b.id ? -1 : (a.id > b.id ? 1 : 0));
                this.quickApps = data;
            });
    },
};
</script>
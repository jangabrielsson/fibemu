<template>
    <section>
        <h3>Types</h3>
        <!-- <AccordionList v-model:state="state" open-multiple-items> -->
        <AccordionList v-model:state="state" open-multiple-items>
            <AccordionItem v-for="(tt,i) in types" :key="tt" :id="i" :default-opened="i === 0">
                <template #summary>{{tt.type}}{{ i }}</template>
                <template #icon>+</template>
                <h4>Properties:</h4>
                <li v-for="(prop,pv,pi) in tt.props" :key="prop" :id="prop">
                    {{ pv }}: {{ prop.type }}
                </li>
                <h4>Interfaces:</h4>
                <li v-for="(iface,iv,ii) in tt.interfaces" :key="iface" :id="iface">
                    {{ iface }}
                </li>
                <h4>Actions:</h4>
                <li v-for="(action,av,ai) in tt.actions" :key="action" :id="action">
                    {{ av }} : {{ action }}
                </li>
            </AccordionItem>
        </AccordionList>
    </section>
</template>

<script>
export default {
    data() {
        return {
            types: {}
        };
    },
    methods: {
        fetchTypes() {
            console.log("Fetching events");
            fetch(this.$store.state.backend+"/emu/types", {
                method: "GET",
                headers: {
                    "Content-Type": "application/json",
                },
            })
                .then((response) => response.json())
                .then((data) => {
                    data = data.sort((a, b) => a.type.localeCompare(b.type, undefined, { sensitivity: 'accent' }));
                    this.types = data;
                });
        }
    },
    mounted() {
        this.fetchTypes();
    }
};
</script>
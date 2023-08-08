<template>
    <div v-if="props.state">
        <h2><span class="badge bg-success">On {{ props.value }}%</span></h2>
    </div>
    <div v-else>
        <h2><span class="badge bg-danger">Off</span></h2>
    </div>
    <h2 v-if="props.dead"><span class="badge bg-danger">Dead</span></h2>
    <h2 v-if="props.batteryLevel"><span class="badge bg-secondary">Battery {{ props.batteryLevel }}%</span></h2>
</template>

<script>
export default {
    props: {
        id: Number,
        props: Object,
    },
    data() {
        return {
        };
    },
    computed: {
        value() {
            return this.props.value;
        },
    },
    watch: {
        value(value) {
            console.log(`Value changed to ${value}`);
            this.$emit("slider-changed", '__value', value)
            fetch(this.$store.state.backend + `/api/plugins/callUIEvent?deviceID=${this.id}&eventType=onChanged&elementName=__value&value=${value}`);
        },
    },
    methods: {
    },
    mounted() {
    }
};
</script>

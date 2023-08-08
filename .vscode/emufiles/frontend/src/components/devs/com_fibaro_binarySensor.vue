<template>
    <div v-if="props.value">
        <h2><span class="badge bg-danger">Breached</span></h2>
    </div>
    <div v-else>
        <h2><span class="badge bg-success">Safe</span></h2>
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
    methods: {
    },
    mounted() {
    }
};
</script>

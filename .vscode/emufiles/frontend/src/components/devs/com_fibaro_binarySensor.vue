<template>
    <div v-if="props.value">
        <h1><span class="badge bg-success">Breached</span></h1>
    </div>
    <div v-else>
        <h1><span class="badge bg-danger">Safe</span></h1>
    </div>
</template>

<script>
export default {
    props: {
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

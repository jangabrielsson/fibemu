<template>
    <div v-if="props.state">
        <h1><span class="badge bg-success">On</span></h1>
    </div>
    <div v-else>
        <h1><span class="badge bg-danger">Off</span></h1>
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

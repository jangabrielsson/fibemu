<template>
    <div v-if="props.state">
        <h1><span class="badge bg-success">{{isOff}} {{props.value}}%</span></h1>
    </div>
    <div v-else>
        <h1><span class="badge bg-danger">{{isOff}}</span></h1>
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
    computed: {
        isOff() {
            const s = this.props.state;
            if (!s) {
                console.log("Emitting slider-changed");
                this.$emit("slider-changed", "__value", 0);
            }
            return this.props.state ? "On" : "Off";
        },
    },
    methods: {
    },
    mounted() {
    }
};
</script>

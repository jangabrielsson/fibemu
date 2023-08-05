<template>
    <div class="card" style="width: 28rem;"></div>
    <h2>Name: {{ dev.name }} </h2>
    <p>Type: {{ dev.type }}</p>
    <quick-app-ui :id="id"></quick-app-ui>
</template>
  
<script>
export default {
    props: {
        id: Number,
    },
    data() {
        return {
            dev: {},
            quickVars: {},
        };
    },
    methods: {
    },
    mounted() {
        console.log("Fetching device2 " + this.id);
        fetch("http://localhost:5004/emu/qa/" + this.id, {
            method: "GET",
            headers: {
                "Content-Type": "application/json",
            },
        })
            .then((response) => response.json())
            .then((data) => {
                console.log("Got device " + JSON.stringify(data.dev.id));
                this.dev = data.dev;
                this.quickVars = data.qvs;
            });
    },
};
</script>
  
<style scoped>
@media (min-width: 1200px) {
    .container {
        max-width: 400px;
    }
}

.btn-secondary {
    color: #000000;
    background-color: #f6f6f6;
    border-color: #c7c7c7;
}

.form-range::-webkit-slider-thumb {
    background: #cdcccc;
}

.form-range::-moz-range-thumb {
    background: #cdcccc;
}

.form-range::-ms-thumb {
    background: #cdcccc;
}

@media (prefers-reduced-motion: reduce) {
    .form-range::-webkit-slider-thumb {
        -webkit-transition: none;
        transition: none;
    }
}

.form-range::-webkit-slider-thumb:active {
    background-color: #FF8000;
}

.form-range::-webkit-slider-runnable-track {
    width: 100%;
    height: 0.5rem;
    color: transparent;
    cursor: pointer;
    background-color: #a0a0a0;
    border-color: transparent;
    border-radius: 1rem;

}
</style>
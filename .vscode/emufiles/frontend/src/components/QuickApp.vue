<template>
    <div class="card" style="width: 28rem;"></div>
    <h5>Type: {{ dev.type }} </h5>
    <hr>
    <quick-app-ui :id="id"></quick-app-ui>
    <hr>
    <AccordionList v-model:state="state" open-multiple-items=true>
        <AccordionItem id="mId1">
            <template #summary>QuickAppVariables</template>
            <template #icon>+</template>
            <ul class="list-group">
                <li v-for="v in quickVars" :key="key" class="list-group-item">
                    <form>
                        {{ v.name }}:
                        <input :value="v.value" @input="v.value = $event.target.value">
                        <button @click.prevent="updateVar(v.name, v.value)">Update</button>
                    </form>
                </li>
            </ul>
        </AccordionItem>
        <AccordionItem id="mId2">
            <template #summary>Device structure</template>
            <template #icon>+</template>
            <pre v-html="JSON.stringify(dev, null, 2)"></pre>
        </AccordionItem>
    </AccordionList>
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
        updateVar(name, value) {
            console.log(`Update var ${name} to ${value}`);
            // fetch(`http://localhost:5004/emu/qa/${this.id}/var/${name}/${value}`, {
            //     method: "GET",
            //     headers: {
            //         "Content-Type": "application/json",
            //     },
            // })
            //     .then((response) => response.json())
            //     .then((data) => {
            //         console.log("Got quickApps " + JSON.stringify(data));
            //         this.quickVars = data;
            //     });
        },
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

.adv {
    display: flex;
    justify-content: center;
    border-bottom: 2px solid gray;
    margin-bottom: 50px;
    &__image {
        font-size: 150px;
    }
}
</style>


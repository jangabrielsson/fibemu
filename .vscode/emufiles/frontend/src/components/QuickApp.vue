<template>
    <div class="card" style="width: 28rem;"></div>
    <h5>Type: {{ dev.type }} </h5>
    <hr>
    <quick-app-ui :id="id" :ui="ui" :dev="dev" :uiMap="uiMap" @change="selectChanged" @slider-changed="sliderReleased"></quick-app-ui>
    <div v-if="disconnected" class="bg-danger text-center text-white">Disconnected</div>
    <hr>
    <!-- <AccordionList v-model:state="state" open-multiple-items> -->
    <AccordionList open-multiple-items>
        <AccordionItem id="mId1">
            <template #summary>QuickAppVariables</template>
            <template #icon>+</template>
            <ul class="list-group">
                <li v-for="v in quickVars" :key="v" class="list-group-item">
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

import QuickAppUI from './QuickAppUI.vue';

export default {
    components: {
        'quick-app-ui': QuickAppUI,
    },

    props: {
        id: Number,
        state: Object,
        start: Boolean,
    },
    data() {
        return {
            dev: {},
            quickVars: {},
            uiMap: {},
            ui: {},
            disconnected: false,
            ref: null,
        };
    },
    watch: {
        state(st, oldSt) {
            // console.log(`State changed ${this.id} ${st} ${oldSt}`);
            if (st[this.id] && this.ref == null) {
                this.ref = setInterval(this.updateQA, 1000);
            } else if (!st[this.id] && this.ref != null) {
                clearInterval(this.ref);
                this.ref = null;
            }
        },
    },
    methods: {
        httpGet(url, callback, timeout) {
            (async () => {
                const controller = new AbortController();
                const timeoutId = setTimeout(() => controller.abort(), timeout);

                try {
                    const response = await fetch(url, {
                        headers: {
                            "Content-Type": "application/json",
                        },
                        signal: controller.signal
                    }).then((res) => res.json());
                    this.disconnected = false;
                    callback(response);
                } catch (error) {
                    this.disconnected = true;
                    console.log("error:" + error.message);
                } finally {
                    clearTimeout(timeoutId);
                }
            })();
        },
        elementUpdate(id, prop, value, ev) {
            console.log(`Element '${id}' prop '${prop}' changed to ${value} -> ${ev}`);
            this.uiMap[id][prop] = value;
        },
        sliderReleased(id, value) {
            console.log(`Slider '${id}' changed to ${value}`);
            this.uiMap[id].value = value;
        },
        selectChanged(id,value) {
            this.uiMap[id].value = value;
        },
        updateQA() {
            console.log(`Refresh QA ${this.id}`);
            this.httpGet(this.$store.state.backend + "/emu/qa/" + this.id, (data) => {
                this.uiMap = data.uiMap;
                this.quickVars = data.quickVars;
                this.dev = data.dev;
            }, this.$store.state.fastPoll);
        },
    },
    mounted() {
        console.log("Mounting device " + this.id);
        this.httpGet(this.$store.state.backend + "/emu/qa/" + this.id, (data) => {
            this.disconnected = false;
            this.dev = data.dev;
            this.ui = data.ui;
            this.uiMap = data.uiMap;
            this.quickVars = data.quickVars;
            if (this.ui.forEach) {
                this.ui.forEach(row => {
                    row.forEach(item => {
                        if (item.type == "slider") {
                            item.id = item.slider;
                        } else if (item.type == "button") {
                            item.id = item.button;
                        } else if (item.type == "label") {
                            item.id = item.label;
                        } else if (item.type == "select") {
                            item.id = item.select;
                        }
                    });
                });
            } else {
                this.ui = [];
            }
        }, 3000);
        if (this.start) {
            this.ref = setInterval(this.updateQA, this.$store.state.mediumPoll);
        }
    },
    unmounted() {
        console.log("Unmounting device " + this.id);
        clearInterval(this.ref);
    }
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

    :is(__image[data-v-85a91b67]) {
        font-size: 150px;
    }
}
</style>


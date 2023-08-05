<template>
  <div class="card" style="width: 28rem;">
    <div class="p-1 container-xs border-primary p-3">
      <div v-for="(row, x) in    ui   " :key="x" class="row p-1">
        <div v-for="item in    row   " :key="item.id" class="col mb-1 d-grid">
          <button v-if="item.type == 'button'" type="button" class="btn btn-secondary"
            @click.prevent="buttonPresssed(item.button)">
            {{ uiMap[item.id].text }}
          </button>
          <div v-else-if="item.type == 'slider'">
            <output>{{ uiMap[item.id].value }}</output>
            <input v-if="item.type == 'slider'" type="range" class="form-range" :id="item.id" tooltips="true"
              :min="uiMap[item.id].min || 0" :max="uiMap[item.id].max || 100" :step="uiMap[item.id].step || 100"
              :value="uiMap[item.id].value || 0" @mouseup="sliderReleased($event.target.id, $event.target.value)">
          </div>
          <div v-else-if="item.type == 'label'" class="text-center">
            {{ uiMap[item.id].text }}
          </div>
        </div>
      </div>
    </div>
    <button @click.prevent="updateUI">Update UI</button>
  </div>
</template>

<script> 
export default {
  props: {
    id: Number,
  },
  data() {
    return {
      dev: {},
      ui: {},
      uiMap: {},
    };
  },
  methods: {
    buttonPresssed(id) {
      console.log(`Button '${id}' pressed`);
      fetch(`http://localhost:5004/api/plugins/callUIEvent?deviceID=${this.id}&eventType=onReleased&elementName=${id}`);
    },
    sliderReleased(id, value) {
      console.log(`Slider '${id}' changed to ${value}`);
      this.uiMap[id].value = value;
      fetch(`http://localhost:5004/api/plugins/callUIEvent?deviceID=${this.id}&eventType=onChanged&elementName=${id}&value=${value}`);
    },
    updateUI() {
      console.log(`Refresh UI ${this.id}`);
      fetch("http://localhost:5004/emu/qa/ui/" + this.id, {
        method: "GET",
        headers: {
          "Content-Type": "application/json",
        },
      })
        .then((response) => response.json())
        .then((data) => {
          this.uiMap = data;
        });
    }
  },
  mounted() {
    console.log("Fetching device " + this.id);
    fetch("http://localhost:5004/emu/qa/" + this.id, {
      method: "GET",
      headers: {
        "Content-Type": "application/json",
      },
    })
      .then((response) => response.json())
      .then((data) => {
        this.dev = data.dev;
        this.ui = data.ui;
        this.uiMap = data.uiMap;
        data.ui.forEach(row => {
          row.forEach(item => {
            if (item.type == "slider") {
              item.id = item.slider;
            } else if (item.type == "button") {
              item.id = item.button;
            } else if (item.type == "label") {
              item.id = item.label;
            }
          });
        });
      });
    this.ref = setInterval(this.updateUI, 1000);
  },
  beforeDestroy() {
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

.card {
  background-color: #ffffff;
  border-color: #000000;
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
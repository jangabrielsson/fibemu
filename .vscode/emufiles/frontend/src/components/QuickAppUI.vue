<template>
  <div class="row">
    <div class="col">
      <div class="card" style="width: 28rem;">
        <div class="p-1 container-xs border-primary p-3">
          <div v-for="(row, x) in ui" :key="x" class="row p-1">
            <div v-for="item in row" :key="item.id" class="col mb-1 d-grid">
              <button v-if="item.type == 'button'" type="button" class="btn btn-secondary"
                @mousedown.prevent="buttonPresssed(item.button)"
                @mouseup.prevent="buttonReleased(item.button)"
                >
                <span v-html="uiMap[item.id].text"></span>
              </button>
              <div v-else-if="item.type == 'slider'">
                <output>{{ uiMap[item.id].value }}</output>
                <input v-if="item.type == 'slider'" type="range" class="form-range" :id="item.id" tooltips="true"
                  :min="uiMap[item.id].min || 0" :max="uiMap[item.id].max || 100" :step="uiMap[item.id].step || 100"
                  :value="uiMap[item.id].value || 0" @mouseup="sliderReleased($event.target.id, $event.target.value)">
              </div>
              <div v-else-if="item.type == 'label'" class="text-center">
                <hr v-if="uiMap[item.id].text === '-------------------------------'">
                <span v-else v-html="uiMap[item.id].text"></span>
              </div>
              <select v-if="item.type == 'select'" :id="item.id"
              @change="selectChanged($event.target.id, $event.target.value)">
                <option disabled selected="true" value="">Choose</option>
                <option v-for="option in uiMap[item.id].options" :selected="uiMap[item.id].selectedItem===option.value" :key="option.value" :value="option.value">
                  {{ option.text }}
                </option>
              </select>
              <button v-if="item.type == 'switch'" type="button" class="btn btn-secondary"
                :style="{'background-color': uiMap[item.id].value === 'true' ? 'blue' : '', 'color': uiMap[item.id].value === 'true' ? 'white' : ''}"
                @click.prevent="switchChanged(item.id, item.value)">
                <span v-html="uiMap[item.id].text"></span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    <div v-if="type === 'com.fibaro.binarySwitch'" class="col">
      <com-fibaro-binarySwitch :id="id" :props="props"></com-fibaro-binarySwitch>
    </div>
    <div v-else-if="type === 'com.fibaro.binarySensor'" class="col">
      <com-fibaro-binarySensor :id="id" :props="props"></com-fibaro-binarySensor>
    </div>
    <div v-else-if="type === 'com.fibaro.multilevelSwitch'" class="col">
      <com-fibaro-multilevelSwitch :id="id" :props="props"></com-fibaro-multilevelSwitch>
    </div>
    <div v-else-if="type === 'com.fibaro.multilevelSensor'" class="col">
      <com-fibaro-multilevelSensor :id="id" :props="props"></com-fibaro-multilevelSensor>
    </div>
    <div v-else-if="type === 'com.fibaro.humiditySensor'" class="col">
      <com-fibaro-humiditySensor :id="id" :props="props"></com-fibaro-humiditySensor>
    </div>
    <div v-else-if="type === 'com.fibaro.temperatureSensor'" class="col">
      <com-fibaro-temperatureSensor :id="id" :props="props"></com-fibaro-temperatureSensor>
    </div>
  </div>
</template>

<script>
import com_fibaro_binarySwitch from "./devs/com_fibaro_binarySwitch.vue";
import com_fibaro_multilevelSwitch from "./devs/com_fibaro_multilevelSwitch.vue";
import com_fibaro_multilevelSensor from "./devs/com_fibaro_multilevelSensor.vue";
import com_fibaro_binarySensor from "./devs/com_fibaro_binarySensor.vue";
import com_fibaro_temperatureSensor from "./devs/com_fibaro_temperatureSensor.vue";
import com_fibaro_humiditySensor from "./devs/com_fibaro_humiditySensor.vue";

export default {
  components: {
    "com-fibaro-binarySwitch": com_fibaro_binarySwitch,
    "com-fibaro-multilevelSwitch": com_fibaro_multilevelSwitch,
    "com-fibaro-multilevelSensor": com_fibaro_multilevelSensor,
    "com-fibaro-binarySensor": com_fibaro_binarySensor,
    "com-fibaro-temperatureSensor": com_fibaro_temperatureSensor,
    "com-fibaro-humiditySensor": com_fibaro_humiditySensor
  },
  props: {
    id: Number,
    dev: Object,
    uiMap: Object,
    ui: Object,
  },
  data() {
    return {
      type: "",
      props: {},
    };
  },
  methods: {
    // press. lastPressed=now; start <timer>
    // release. cancel Timer if lastPressed < 750 <onReleased> else <onLongPressReleased>
    // <timer> >= 750 <onLongPressDown>
    buttonReleased(id) {
      console.log(`Button '${id}' released`);
      fetch(this.$store.state.backend + `/api/plugins/callUIEvent?deviceID=${this.id}&eventType=onReleased&elementName=${id}`);
    },
    buttonPresssed(id) {
      console.log(`Button '${id}' pressed`);
      this.uiMap[id].lastPressed = new Date().getTime();
      //fetch(this.$store.state.backend + `/api/plugins/callUIEvent?deviceID=${this.id}&eventType=onPressed&elementName=${id}`);
    },
    sliderReleased(id, value) {
      // console.log(`Slider '${id}' changed to ${value}`);
      // this.uiMap[id].value = value;
      this.$emit("slider-changed", id, value)
      fetch(this.$store.state.backend + `/api/plugins/callUIEvent?deviceID=${this.id}&eventType=onChanged&elementName=${id}&value=${value}`);
    },
    selectChanged(id,value) {
      console.log(`Select '${id}' = '${value}'`);
      //this.$emit("select-changed", id, value)
      //{"eventType":"onToggled","deviceId":1245,"values":["auto"],"elementName":"modeSelector"}
      fetch(this.$store.state.backend + `/api/plugins/callUIEvent?deviceID=${this.id}&eventType=onToggled&elementName=${id}&value=${value}`);
    },
    switchChanged(id,value) {
      value = this.uiMap[id].value === "true" ? "false" : "true";
      console.log(`Switch '${id}' pressed '${value}'`);
      this.uiMap[id].value = value;
      fetch(this.$store.state.backend + `/api/plugins/callUIEvent?deviceID=${this.id}&eventType=onReleased&elementName=${id}&value=${value}`);
    },
  },
  watch: {
    dev: function (dev) {
      this.type = dev.type;
      this.props = dev.properties;
    },
  },
  mounted() {
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
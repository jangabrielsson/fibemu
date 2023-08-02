<template>
  <li>
    <h2>{{ name }} {{  isEnabled ? '(enabled)' : "" }} </h2>
    <button @click="toggleDetails">Show Details</button>
    <button @click="toggleEnabled">{{isEnabled ? 'Disable' : 'Enable'}}</button>
    <ul v-if="detailsAreVisible">
      <li>
        <strong>Id:</strong>
        {{ qid }}
      </li>
      <li>
        <strong>Type:</strong>
        {{ type }}
      </li>
    </ul>
  </li>
</template>

<script>
export default {
  props: {
    qid: Number,
    name: String,
    type: String,
    isEnabled: {
      type: Boolean,
      required: false,
      default: false,
    }
  },
  emits: ['toggle-enabled'],
  data() {
    return {
      detailsAreVisible: false,
    };
  },
  methods: {
    toggleDetails() {
      this.detailsAreVisible = !this.detailsAreVisible;
    },
    toggleEnabled() {
      this.$emit('toggle-enabled', this.qid);
    }
  }
};
</script>
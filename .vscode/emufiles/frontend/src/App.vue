<template>
  <section>
    <header>
      <h1>QuickApps</h1>
    </header>
    <ul>
      <quick-app v-for="qa in quickApps" :key="qa.id" :id="qa.id"></quick-app>
    </ul>
  </section>
</template>

<script>
export default {
  data() {
    return {
      quickApps: [],
    };
  },
  methods: {
  },
  mounted() {
    fetch("http://192.168.1.129:5004/emu/qa", {
      method: "GET",
      headers: {
        "Content-Type": "application/json",
      },
    })
      .then((response) => response.json())
      .then((data) => {
        // console.log("Got quickApps " + JSON.stringify(data));
        this.quickApps = data;
      });
  },
};
</script>

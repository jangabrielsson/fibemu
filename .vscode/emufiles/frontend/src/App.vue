<template>
  <section>
    <header>
      <h1>QuickApps</h1>
    </header>
  
    
    <ul>
      <quick-app 
        v-for="qa in quickApps"
        :key="qa.qid"
        :qid="qa.qid" 
        :name="qa.name" 
        :type="qa.type"
        :is-enabled="qa.isEnabled"
        @toggle-enabled="toggleEnabled"
        ></quick-app>
    </ul>
  </section>
</template>

<script>
export default {
  data() {
    return {
      quickApps: [
        {
          qid: 56,
          name: "QuickApp A",
          type: "com.fibaro.binarySwitch",
          isEnabled: true,
        },
        {
          qid: 57,
          name: "QuickApp B",
          type: "com.fibaro.multilevelSwitch",
          isEnabled: false,
        },
      ],
    };
  },
  methods: {
    toggleEnabled(qid) {
      const qa = this.quickApps.find(qa => qa.qid === qid);
      qa.isEnabled = !qa.isEnabled;
    },
  },
};
</script>

<style>
* {
  box-sizing: border-box;
}

html {
  font-family: "Jost", sans-serif;
}

body {
  margin: 0;
}

header {
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.26);
  margin: 3rem auto;
  border-radius: 10px;
  padding: 1rem;
  background-color: #58004d;
  color: white;
  text-align: center;
  width: 90%;
  max-width: 40rem;
}

#app ul {
  margin: 0;
  padding: 0;
  list-style: none;
}

#app li {
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.26);
  margin: 1rem auto;
  border-radius: 10px;
  padding: 1rem;
  text-align: center;
  width: 90%;
  max-width: 40rem;
}

#app h2 {
  font-size: 2rem;
  border-bottom: 4px solid #ccc;
  color: #58004d;
  margin: 0 0 1rem 0;
}

#app button {
  font: inherit;
  cursor: pointer;
  border: 1px solid #ff0077;
  background-color: #ff0077;
  color: white;
  padding: 0.05rem 1rem;
  box-shadow: 1px 1px 2px rgba(0, 0, 0, 0.26);
}

#app button:hover,
#app button:active {
  background-color: #ec3169;
  border-color: #ec3169;
  box-shadow: 1px 1px 4px rgba(0, 0, 0, 0.26);
}
</style>
<template>
  <section>
    <header>
    </header>
    <menu-bar></menu-bar>
    <router-view></router-view>
  </section>
  <div id="footer">
    &copy; Copyleft 2023 by <a href="http://domain.invalid/">Jan Gabrielsson</a>.
  </div>
</template>

<script>
export default {
  data() {
    return {
      panel: "quick-app-panel",
    };
  },
  methods: {
  },
  mounted() {
  }
};
</script>

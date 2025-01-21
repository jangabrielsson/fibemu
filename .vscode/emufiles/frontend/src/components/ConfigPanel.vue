<template>
    <h3>Config</h3>
    <table class="table">
        <thead>
            <tr>
                <th class="col-1">Nme</th>
                <th class="col">Value</th>
            </tr>
        </thead>
        <tbody>
            <tr v-for="cfg in config">
                <td>{{ cfg.name }}</td>
                <td>
                    <template v-if="typeof cfg.value === 'object' && cfg.value !== null">
                        <div v-for="(key, value) in cfg.value" :key="value">
                            {{ value }}: {{ key }}<br/>
                        </div>
                    </template>
                    <template v-else>
                        {{  cfg.value }}
                    </template>
                </td>
            </tr>
        </tbody>
    </table>
</template>

<script>
export default {
    data() {
        return {
            config: [],
        };
    },
    methods: {
        fetchConfig() {
            console.log('Fetching config');
            fetch(this.$store.state.backend + "/emu/config", {
                method: "GET",
                headers: {
                    "Content-Type": "application/json",
                },
            })
                .then((response) => response.json())
                .then((data) => {
                    data.sort((a, b) => a.name < b.name ? -1 : (a.name > b.name ? 1 : 0));
                    this.config = data;
                });
        }
    },
    mounted() {
        console.log("Mounted");
        this.fetchConfig();
    },
    unmounted() {
        console.log("Unmounted");
    },
};
</script>
<template>
    <h3>GlobalVariables</h3>
    <table class="table">
        <thead>
            <tr>
                <th class="col-1">Modified</th>
                <th class="col-1">Name</th>
                <th class="col">Value</th>
            </tr>
        </thead>
        <tbody>
            <tr v-for="global in globals" :key="global">
                <td>{{ totime(global.modified) }}</td>
                <td>{{ global.name }}</td>
                <td>
                    <form>
                        <input :value="global.value" @input="global.value = $event.target.value">
                        <button @click.prevent="updateVar(global.name, global.value)">Update</button>
                    </form>
                </td>
            </tr>
        </tbody>
    </table>
</template>

<script>
export default {
    data() {
        return {
            globals: {},
            ref: null,
        };
    },
    methods: {
        totime(val) {
            return new Date(1000 * val).toLocaleString();
        },
        fetchGlobals() {
            console.log("Fetching globals");
            fetch(this.$store.state.backend+"/api/globalVariables", {
                method: "GET",
                headers: {
                    "Content-Type": "application/json",
                },
            })
                .then((response) => response.json())
                .then((data) => {
                    data.sort((a, b) => a.name < b.name ? -1 : (a.name > b.name ? 1 : 0));
                    this.globals = data;
                });
        }
    },
    mounted() {
        console.log("Mounted");
        this.fetchGlobals();
        this.ref = setInterval(this.fetchGlobals, this.$store.state.mediumPoll);
    },
    unmounted() {
        console.log("Unmounted");
        if (this.ref) clearInterval(this.ref);
    },
};
</script>

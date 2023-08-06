<template>
    <h3>Events</h3>
    <table class="table">
        <thead>
            <tr>
                <th class="col-1">Time</th>
                <th class="col">Type</th>
                <th class="col">Data</th>
            </tr>
        </thead>
        <tbody>
            <tr v-for="event in events" :key="event">
                <td>{{ totime(event.event.created) }}</td>
                <td>{{ event.event.type }}</td>
                <td>{{ event.event.data }}</td>
            </tr>
        </tbody>
    </table>
</template>

<script>
export default {
    data() {
        return {
            events: {},
            ref: null,
        };
    },
    methods: {
        totime(val) {
            return new Date(1000*val).toLocaleTimeString();
        },
        fetchEvents() {
            console.log("Fetching events");
            fetch("http://localhost:5004/emu/events", {
                method: "GET",
                headers: {
                    "Content-Type": "application/json",
                },
            })
                .then((response) => response.json())
                .then((data) => {
                    data.sort((a, b) => a.event.created > b.event.created ? -1 : (a.event.created < b.event.created ? 1 : 0));
                    this.events = data;
                });
        }
    },
    mounted() {
        this.fetchEvents();
        this.ref = setInterval(this.fetchEvents, 1000);
    },
    beforeDestroy() {
        clearInterval(this.ref);
    }
};
</script>
<template>
    <!-- Color Variant -->
    <nav class="navbar navbar-expand-md bg-primary navbar-dark">
        <div class="container">
            <a href="#" class="navbar-brand">Fibemu</a>
            <button type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav" class="navbar-toggler">
                <span class="navbar-toggler-icon"></span>
            </button>

            <div class="collapse navbar-collapse" id="navbarNav">
                <ul class="navbar-nav ms-auto">
                    <li class="nav-item">
                        <router-link class="nav-link" to="/frontend/home">Home</router-link>
                    </li>
                    <li class="nav-item">
                        <router-link class="nav-link" to="/frontend/events">Events</router-link>
                    </li>
                    <li class="nav-item">
                        <router-link class="nav-link" to="/frontend/globals">GlobalVariables</router-link>
                    </li>
                    <li class="nav-item">
                        <router-link class="nav-link" to="/frontend/config">Config</router-link>
                    </li>
                    <li class="nav-item">
                        <router-link class="nav-link" to="/frontend/about">About</router-link>
                    </li>
                </ul>
            </div>
        </div>
    </nav>
</template>
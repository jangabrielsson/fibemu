<template>
    <div>
    <h1>4040</h1>
    <image :src = "require('../assets/404.png')" alt="404"/>
    </div>
</template>

<script>
import imgUrl from '/404.png'
export default {
  data() {
    return{
      image: imgUrl,
    };
  },
  mounted() {
    console.log("Image " + imgUrl)
  }
}
</script>
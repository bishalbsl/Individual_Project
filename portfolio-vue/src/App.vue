<template>
  <div id="app">
    <NavBar/>
    <Header/>
    <About/>
    <Skills/>
    <Qualification/>
    <Portfolio/>
    <Footer/>
    
  </div>
</template>

<script>
// import HelloWorld from './components/HelloWorld.vue'
import NavBar from './components/NavBar.vue'
import Header from './components/Header.vue'
import About from './components/About.vue'
import Skills from './components/Skills.vue'
import Qualification from './components/Qualification.vue'
import Portfolio from './components/Portfolio.vue'
import Footer from './components/Footer.vue'

export default {
  name: 'App',
  components: {
    // HelloWorld,
    NavBar,
    Header,
    About,
    Skills,
    Qualification,
    Portfolio,
    Footer,

  }
}
</script>

<style>
#app {
  font-family: Avenir, Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-align: center;
  color: #2c3e50;
  margin-top: 60px;
}
</style>

import Vue from 'vue'
import App from './App.vue'
/* import the fontawesome core */
import { library } from '@fortawesome/fontawesome-svg-core'

/* import specific icons */
import { faEnvelope } from '@fortawesome/free-solid-svg-icons'
import { faLinkedinIn, faFacebook } from '@fortawesome/free-brands-svg-icons'

/* import font awesome icon component */
import { FontAwesomeIcon } from '@fortawesome/vue-fontawesome'

import VueI18n from 'vue-i18n';

/* add icons to the library */
library.add(faEnvelope, faLinkedinIn, faFacebook)

/* add font awesome icon component */
Vue.component('font-awesome-icon', FontAwesomeIcon)


Vue.config.productionTip = false
Vue.use(VueI18n)

new Vue({
    render: h => h(App),
}).$mount('#app')
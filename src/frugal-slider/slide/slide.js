var animate = require('gsap-promise');

module.exports = {
  template: `
    <div class="slide">
      <img class="slide-image" src="{{currentSlide.url}}" />
    </div>
  `,
  replace: true,
  paramAttributes: ['incoming-slide'],
  data: function () {
    return {
      currentSlide: undefined
    };
  },
  watch: {
    incomingSlide: async function (incomingSlide) {
      if (!this.currentSlide) {
        this.currentSlide = incomingSlide;
      } else {
        await this.animateOut();
        this.currentSlide = incomingSlide;
        await this.animateIn();
      }
    }
  },
  ready: function () {
    this.animateIn();
  },
  methods: {
    animateIn: function () {
      return animate.fromTo($(this.$el), 0.5, {opacity: 0, x: 50}, {opacity: 1, x: 0});
    },
    animateOut: function () {
      return animate.to($(this.$el), 0.5, {opacity: 0, x: -50});
    }
  }
}
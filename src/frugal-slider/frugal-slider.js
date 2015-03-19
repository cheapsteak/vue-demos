var slides = require('./mock-data');

module.exports = {
  template: require('./frugal-slider.html'),
  replace: true,
  data: function () {
    return {
      currentSlide: slides[0]
    }
  },
  computed: {
    currentSlideIndex: function () {
      return slides.indexOf(this.currentSlide);
    },
    previousSlide: function () {
      var hasPreviousSlide = this.currentSlideIndex > 0;
      return hasPreviousSlide
        ? slides[this.currentSlideIndex - 1]
        : slides[slides.length - 1]
    },
    nextSlide: function () {
      var hasNextSlide = this.currentSlideIndex < (slides.length - 1);
      return hasNextSlide
        ? slides[this.currentSlideIndex + 1]
        : slides[0]
    }
  },
  methods: {
    toNextSlide: function () {
      this.currentSlide = this.nextSlide;
    },
    toPreviousSlide: function () {
      this.currentSlide = this.previousSlide;
    },
  },
  components: {
    slide: require('./slide/slide')
  }
};
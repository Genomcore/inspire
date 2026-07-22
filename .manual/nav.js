// INSPIRE manual — shared nav behavior (index.html + skills.html + how-to.html)
(function () {
  var reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  // Primary nav gains a hairline border once the page is scrolled
  var nav = document.getElementById('nav');
  if (nav) {
    var onScroll = function () { nav.classList.toggle('scrolled', window.scrollY > 12); };
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
  }

  // Gentle reveal-on-scroll
  var items = document.querySelectorAll('.reveal');
  if (reduce || !('IntersectionObserver' in window)) {
    items.forEach(function (el) { el.classList.add('in'); });
  } else {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); }
      });
    }, { threshold: 0.14, rootMargin: '0px 0px -8% 0px' });
    items.forEach(function (el) { io.observe(el); });
  }

  // Secondary nav — highlight the section currently in view (scroll-spy)
  var links = Array.prototype.slice.call(document.querySelectorAll('.subnav-in a'));
  if (links.length && 'IntersectionObserver' in window) {
    var byId = {};
    var sections = links.map(function (a) {
      var id = (a.getAttribute('href') || '').split('#')[1];
      var el = id && document.getElementById(id);
      if (el) byId[id] = a;
      return el;
    }).filter(Boolean);

    if (sections.length) {
      var spy = new IntersectionObserver(function (entries) {
        entries.forEach(function (e) {
          if (!e.isIntersecting) return;
          links.forEach(function (l) { l.classList.remove('active'); });
          var a = byId[e.target.id];
          if (a) {
            a.classList.add('active');
            // keep the active pill in view within the horizontally-scrolling bar
            if (a.scrollIntoView) a.scrollIntoView({ block: 'nearest', inline: 'nearest' });
          }
        });
      }, { rootMargin: '-45% 0px -50% 0px', threshold: 0 });
      sections.forEach(function (s) { spy.observe(s); });
    }
  }
})();

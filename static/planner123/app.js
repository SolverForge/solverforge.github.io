/* ============================================================
   Planner123 Landing Page — app.js
   Vanilla JS. No dependencies.
   ============================================================ */

(function () {
  'use strict';

  // --- Section reveal on scroll ---
  const revealObserver = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add('visible');
          revealObserver.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.15 }
  );

  document.querySelectorAll('.reveal').forEach((el) => {
    revealObserver.observe(el);
  });

  // --- Animated counter for the moves/second stat ---
  const counterEl = document.querySelector('[data-counter]');

  if (counterEl) {
    const target = parseInt(counterEl.dataset.counter, 10);
    const suffix = counterEl.dataset.suffix || '';
    let started = false;

    function formatNumber(n) {
      // Format as X.XXM+ for millions
      if (n >= 1000000) {
        return (n / 1000000).toFixed(2) + 'M';
      }
      return n.toLocaleString('en-US');
    }

    function animateCounter() {
      if (started) return;
      started = true;

      const duration = 2000; // ms
      const start = performance.now();

      function step(now) {
        const elapsed = now - start;
        const progress = Math.min(elapsed / duration, 1);

        // Ease-out cubic
        const eased = 1 - Math.pow(1 - progress, 3);
        const current = Math.floor(eased * target);

        counterEl.textContent = formatNumber(current) + suffix;

        if (progress < 1) {
          requestAnimationFrame(step);
        } else {
          counterEl.textContent = formatNumber(target) + suffix;
        }
      }

      requestAnimationFrame(step);
    }

    const counterObserver = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            animateCounter();
            counterObserver.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.3 }
    );

    counterObserver.observe(counterEl);
  }

  // --- Stage Manager screenshot switcher ---
  const stage = document.getElementById('stage');

  if (stage) {
    const mainImg   = document.getElementById('stage-main-img');
    const mainLabel = document.getElementById('stage-main-label');
    const thumbs    = Array.from(stage.querySelectorAll('.stage__thumb'));

    // Data for all 3 screens
    const screens = [
      { src: 'plan.png',     alt: 'Planner123 — Plan view',     label: 'Plan'     },
      { src: 'gantt.png',    alt: 'Planner123 — Gantt view',    label: 'Gantt'    },
      { src: 'calendar.png', alt: 'Planner123 — Calendar view', label: 'Calendar' },
    ];

    // current = index into screens[] that is on the main stage
    let current = 0;
    // side = the other two, in order
    let sideOrder = [1, 2];

    function renderSide() {
      thumbs.forEach((thumb, t) => {
        const s = screens[sideOrder[t]];
        thumb.querySelector('img').src = s.src;
        thumb.querySelector('img').alt = s.alt;
        thumb.querySelector('.stage__thumb-label').textContent = s.label;
        thumb.dataset.idx = sideOrder[t];
      });
    }

    renderSide();

    thumbs.forEach((thumb) => {
      thumb.addEventListener('click', () => {
        const clicked = parseInt(thumb.dataset.idx, 10);

        // Crossfade main image out
        mainImg.classList.add('stage--swapping');

        setTimeout(() => {
          // Swap: clicked goes to main, current goes into the side slot vacated
          const clickedSidePos = sideOrder.indexOf(clicked);
          sideOrder[clickedSidePos] = current;
          current = clicked;

          // Update main
          mainImg.src = screens[current].src;
          mainImg.alt = screens[current].alt;
          mainLabel.textContent = screens[current].label;

          // Update side
          renderSide();

          // Fade main back in
          mainImg.classList.remove('stage--swapping');
        }, 220);
      });
    });
  }

  // --- YouTube embed loader ---
  // Replaces placeholder with iframe when a valid video ID is set
  const videoContainer = document.querySelector('[data-video-id]');

  if (videoContainer) {
    const videoId = videoContainer.dataset.videoId;

    if (videoId && videoId !== 'REPLACE_ME') {
      const placeholder = videoContainer.querySelector('.video__placeholder');
      if (placeholder) placeholder.remove();

      const iframe = document.createElement('iframe');
      iframe.src =
        'https://www.youtube-nocookie.com/embed/' +
        videoId +
        '?rel=0&modestbranding=1';
      iframe.allow =
        'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture';
      iframe.allowFullscreen = true;
      iframe.loading = 'lazy';
      iframe.title = 'Planner123 demo';
      videoContainer.appendChild(iframe);
    }
  }

  // --- Lightbox for showcase screenshots ---
  const lightbox  = document.getElementById('lightbox');
  const lbImg     = document.getElementById('lightbox-img');

  if (lightbox && lbImg) {
    // Open: click any [data-lightbox] figure's image
    document.querySelectorAll('[data-lightbox]').forEach(function (fig) {
      fig.addEventListener('click', function () {
        var img = fig.querySelector('.showcase__frame img');
        if (!img) return;
        lbImg.src = img.src;
        lbImg.alt = img.alt;
        lightbox.classList.add('lightbox--open');
        lightbox.setAttribute('aria-hidden', 'false');
        document.body.style.overflow = 'hidden';
      });
    });

    // Close: click backdrop, close button, or press Escape
    function closeLightbox() {
      lightbox.classList.remove('lightbox--open');
      lightbox.setAttribute('aria-hidden', 'true');
      document.body.style.overflow = '';
    }

    lightbox.addEventListener('click', function (e) {
      // Don't close when clicking the image itself (unless user wants to)
      if (e.target === lbImg) return;
      closeLightbox();
    });

    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && lightbox.classList.contains('lightbox--open')) {
        closeLightbox();
      }
    });
  }
})();

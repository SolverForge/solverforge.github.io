---
title: Search
eyebrow: Search
layout: default
page_class: page-search
search_exclude: true
---

<section class="search-page">
  <%= render Shared::SearchSurface.new(mode: :page, index_url: relative_url('/search-index.json'), page_url: relative_url('/search/')) %>
</section>

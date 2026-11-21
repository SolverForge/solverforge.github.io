---
title: "Pick-up and delivery routing data"
linkTitle: "Data"
description: >
  The dataset format of the pick-up and delivery routing model: every table at its JSON path,
  every field the model reads, the model's parameters.
---

A dataset is one JSON document. These are its tables, each at its JSON path,
with every field the model reads. The Workbench data editor shows the same
tables with a typed editor per field. What each field does to the score is
explained with the rules on the [constraints page](../constraints/).

<%= render Workbench::DataReference.new(site: site, model: "pickup-delivery-routing") %>

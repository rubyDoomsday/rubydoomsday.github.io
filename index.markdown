---
layout: home
title: Allow Me To Introduce Myself
cover_image: /assets/img/introduction-pic.png
cover_image_alt: introductions image
profile_picture:
  src: /assets/img/profile-pic.jpg
  alt: profile pic
---

# Engineer. Creative. Nomad.

Welcome to my world of exploration and innovation! I'm not your typical software engineer; I'm a dynamic force driven by a passion for
crafting well-architected solutions. With a 'documentation-first' mindset and a knack for rallying remote teams, I fearlessly dive into
every project, ensuring excellence at every turn.

## - Here's the twist -

When I'm not glued to my trusty laptop, I'm on the move! Traversing the country, seeking new adventures, and soaking up the
wonders that life has to offer. I believe these two passions are connected. Doing what you love and loving what you do.

![nomad photo](/assets/img/vanlife.jpg)

Join me as I blend the realms of technology and travel, weaving captivating stories of my adventures on the road and
sharing insightful articles about software and data engineering along the way. Let's embark on this journey together!

## Do What You Love

{% assign item =  site.pages | where:"slug","/play" | first %}
{{ item.content | strip_html | truncatewords:11 }} [read more]({% link play.markdown %})

## Love What You Do

{% assign item =  site.pages | where:"slug","/work" | first %}
{{ item.content | strip_html | truncatewords:10 }} [read more]({% link work.markdown %})

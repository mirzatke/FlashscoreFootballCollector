# v43 Discovery 64 Fix

- Removed the unreliable `data-start-time` archive date filter.
- On the World Championship 2022 results page, archive discovery now accepts the first 64 unique match event nodes in Flashscore newest-first DOM order.
- The existing queue writer reverses those 64 matches into chronological order, from the opening group match through the final.
- Discovery stops clicking `Show more` as soon as 64 unique matches are available.
- Qualification matches below the first 64 final-tournament results are not added.

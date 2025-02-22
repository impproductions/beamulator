# Roadmap

## Next
- query actors tool + example ✅
- destroy actors tool + example ✅
- manual controls
  - spawn actors at runtime ✅
  - monitor application (dashboard) ✅
- connectors
  - rest
  - ws?
  - pg?
  - Opensearch?
- action logger on db
  - action replay?

## Feature ideas
- save state!!! (ugh)
- fuzzer (fuzzy actor example?)
- python behaviours
- add new behaviours at runtime
- restore state from target

## Improvements
- use pubsub for tick
- action logger interface requires knowledge about {__MODULE, name}, make it more explicit in typing (struct?) <- macro?
- uniform error handling
- better logging
- dashboard: better terminal renderer
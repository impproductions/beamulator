# Roadmap

## Next
- executor should be a process and execute asynchronously
- verify message queueing
- monitor actor internals (ie mailbox)
- dispatch ticks through registry
- configure example/simulation path
- connectors
  - rest 🛠️
  - ws?
  - pg?
  - Opensearch?

## Feature ideas
- save/restore state!!! (ugh)
- python behaviours
- fuzzer (fuzzy actor example?)
- action replay?
- restore state from target
- add new behaviours at runtime

## Improvements
- use pubsub for tick
- uniform error handling
- dashboard: better terminal renderer
- fix module redefinition

## Just thinking
- rename behavior to personality to avoid confusion with elixir's behaviour keyword
- rename project to beamulator

## Done
- better logging ✅
- query actors tool + example ✅
- destroy actors tool + example ✅
- spawn actors at runtime ✅
- monitor application (dashboard) ✅
- action logger on db ✅
- simplify action execution with a macro ✅

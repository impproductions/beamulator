# Roadmap

## Next
- executor should be a process and execute asynchronously?
- actor complaint
- verify message queueing
- monitor actor internals (ie mailbox)
- dispatch ticks through registry
- stagger actor starts
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
- configure simulations at runtime
  - extract behavior creation to lab

## Improvements
- document/enforce simulation folder/namespacing
- tests
- use pubsub for tick
- uniform error handling
- dashboard: better terminal renderer
- fix module redefinition

## Just thinking
- rename behavior to personality to avoid confusion with elixir's behaviour keyword
- rename project to beamulator

## Done
- single source for example/simulation path ✅
- better logging ✅
- query actors tool + example ✅
- destroy actors tool + example ✅
- spawn actors at runtime ✅
- monitor application (dashboard) ✅
- action logger on db ✅
- simplify action execution with a macro ✅

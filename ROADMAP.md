# Roadmap

## Next
- switch to self-scheduling actors 🛠️
- actor complaint
- ~~dispatch ticks through registry~~
- stagger actor starts
- action log should include failed requests
- check if one actor dying kills all other actors
- find a way to store runtime config along with simulation
- reintroduce actor config into the mix
- connectors
  - rest 🛠️
  - ws?
  - pg?
  - Opensearch?

## Fix
- behaviors in dashboard are broken
- find a controlled way to handle behavior loading

## Think about this
- should executor be a process (or set of processes) and execute asynchronously?
- remove behavior registry altogether?

## Feature ideas
- save/restore state!!! (ugh)
- python behaviours
- fuzzer (fuzzy actor example?)
- action replay?
- restore state from target
- add new behaviours at runtime
- graphic dashboard
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
- verify message queueing ✅
- monitor actor internals (ie mailbox) ✅
- single source for example/simulation path ✅
- better logging ✅
- query actors tool + example ✅
- destroy actors tool + example ✅
- spawn actors at runtime ✅
- monitor application (dashboard) ✅
- action logger on db ✅
- simplify action execution with a macro ✅

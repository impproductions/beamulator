# Roadmap

## Next
- multi-tenant todo example
- graphic dashboard
- action log should include failed requests
- normalize wait times to "simulated time" instead of ticks
- check if one actor dying kills all other actors
- find a way to store runtime config along with simulation
- reintroduce actor config into the mix
- connectors
  - rest 🛠️
  - ws?
  - pg?
  - Opensearch?

## Fix
- **write in batch on action logger**
- make actors restart after process dies
- inject correct ws url
- can I have the same port for ws and http?

## Feature ideas
- save/restore state!!! (ugh)
- python behaviours
- fuzzer (fuzzy actor example?)
- action replay?
- restore state from target
- add new behaviours at runtime
- limit run duration
- configure simulations at runtime
  - extract behavior creation to lab

## Improvements
- find a controlled way to handle behavior loading?
- document/enforce simulation folder/namespacing
- tests
- uniform error handling
- dashboard: better terminal renderer

## Just thinking
- ~~should executor be a process (or set of processes) and execute asynchronously?~~
- remove behavior registry altogether?
- rename behavior to personality to avoid confusion with elixir's behaviour keyword

## Done
- refactor questdb writer ✅
- behaviors in dashboard are broken ✅
- actor complaint ✅
- rename project to beamulator ✅
- switch to self-scheduling actors ✅
- inject actor data in logger ✅
- store uuid before setting random seed ✅
- stagger actor starts ✅
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

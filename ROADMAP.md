# Roadmap

## Next
- reintroduce actor config into the mix
- find a way to store runtime config along with simulation
- check if one actor dying kills all other actors
- multi-tenant todo example
- ws log connection

## Fix
- **write in batch on action logger**
- inject correct ws url
- created actors don't show up in ui
- rationalize type signatures for large tuples (convert to maps)
  - action executor
  - behavior registry/behavior spec?

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
- document/enforce simulation folder/namespacing
- tests
- uniform error handling
~~- dashboard: better terminal renderer~~

## Just thinking
- find a controlled way to handle behavior loading?
- remove behavior registry altogether?ß
- rename behavior to personality to avoid confusion with elixir's behaviour keyword
- simple connectors?
  - rest?
  - ws?
  - pg?
  - Opensearch?

## Done
- normalize wait times to "simulation time" instead of ticks ✅
- action log should include failed requests ✅
- can I have the same port for ws and http? ✅
- graphic dashboard ✅
- make actors restart after process dies ✅
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

# Blackbox Activity Inference Brainstorming

This document holds the activity inference realism branch that was split out of the main brainstorming document to keep the main file readable.

## Brainstorming Branch 1: Activity Inference Realism

This section is about what the product should realistically expect to infer from iPhone + Apple Watch data, without assuming magic and without prematurely limiting ambition.

### Core Principle

The app should distinguish between:
- what can be inferred reliably enough to drive default UX
- what can be inferred plausibly enough to suggest or tag
- what is too weak to treat as a primary class without user help

This matters because the credibility of the whole product depends on getting the high-confidence cases mostly right and being honest about the fuzzy ones.

### Likely Signal Sources

Without getting implementation-specific yet, the relevant classes of signals likely include:
- location and route geometry
- speed and acceleration patterns
- elevation change over time
- pause and stop structure
- phone motion patterns
- watch motion patterns
- heart rate and other physiological changes when available
- environmental context inferred from map/location context
- time structure and transition context

The important point is that many useful classifications will be multi-signal in nature rather than coming from one decisive sensor.

### Activities That Are Likely Easier

These seem like the most realistic early wins:
- stationary
- walking
- running
- cycling
- generic vehicle travel
- generic flight

Why these are easier:
- they tend to have clearer speed bands or motion signatures
- they are common enough to build intuition around
- the distinction is often already meaningful even without deeper subtype resolution

Tentative product stance:
- these should be treated as core v1 targets

### Activities That Are Likely Moderate Difficulty

These seem possible, but less certain:
- hiking vs running
- driving vs generic vehicle
- commercial flight vs generic flight
- sleep vs quiet stationary periods
- mixed outings with repeated pauses and resumptions

Why they are harder:
- they require contextual interpretation, not just motion pattern recognition
- they may blur together depending on terrain, behavior, or sensor quality

Tentative product stance:
- these can be worthwhile in v1 if represented with confidence and review pathways

### Activities That Are Likely Hard

These seem significantly more difficult to infer robustly in a passive system:
- motorcycle vs car
- train vs bus
- swimming vs rowing
- sailing vs speed boat
- specific watercraft classes
- nuanced subtypes of hiking, trail running, or off-road riding

Why they are hard:
- similar speeds or route structures can mask different underlying activities
- the device may not be positioned consistently enough to expose a stable motion signature
- contextual clues may help, but may still not be decisive

Tentative product stance:
- these should probably begin as secondary subtype guesses, not primary visible classes

### Water Activities

Water is probably its own problem space.

Practical reality:
- "water activity" may be a much safer first-level class than trying to distinguish swimming, rowing, sailing, and motor boating immediately

Potential clues:
- location relative to bodies of water
- pace and continuity of movement
- cadence-like rhythmic patterns
- whether motion looks human-powered or vehicle-like
- stop/start behavior

Suggested stance:
- broad first, refine later only when evidence is unusually strong

### Flight Detection

Flight is probably viable as a broad class.

What may make it workable:
- airport-like departure context
- ground movement before takeoff
- abrupt transition into very high-speed travel
- sparse or degraded normal location during airborne phase
- arrival far away near another airport-like context
- resumed local movement after landing

Suggested stance:
- "flight" is a realistic target
- "commercial flight" should probably be a higher-level interpretation layered on top of flight when context supports it

### Hiking vs Running vs Walking

This family of classes is important because it sits close to your core use cases.

Likely clues:
- pace
- cadence
- elevation profile
- pause frequency
- route type and terrain context
- heart rate profile
- duration and continuity

Suggested stance:
- walking and running are likely good core classes
- hiking may be inferable well enough to be useful, but it will probably need context and may sometimes overlap with walking or trail running

### Driving and Vehicle Modes

Vehicle travel is almost certainly useful as a class.

The harder question is how deep to go.

Possible layered approach:
- first infer vehicle travel
- then try to refine into likely driving, train, bus, motorcycle, etc.
- expose only the refinement when confidence is strong enough

This is a good example of where internal subtype tracking may matter more than early UI complexity.

### The Importance of "Unknown", "Mixed", and "Possible"

Given your preferences, the product should explicitly support:
- unknown
- mixed activity
- possible subtype
- uncertain segment

This is important because it lets the app remain useful even when the classifier is only partially confident.

### Realistic v1 Inference Target

If I had to propose a realistic v1 target set today, it would be:
- stationary
- walking
- running
- hiking
- cycling
- vehicle
- flight
- water activity
- sleep later, not as part of initial movement scope
- unknown / mixed / uncertain as first-class outcomes

And then internally track possible refinements such as:
- driving
- motorcycle
- train
- bus
- swimming
- rowing
- sailing
- speed boat
- commercial flight

### Product Recommendation From This Realism Pass

The product should optimize for:
- broad correct primary classes
- preserved evidence for later reinterpretation
- internal subtype candidates
- strong ambiguity handling
- user corrections as a normal part of the system

That combination gives you room to improve sophistication over time without undermining trust early.

## Questions For This Branch

These are the next questions specifically for activity inference realism.

### 1. v1 Visible Classes

Does this visible v1 class set feel right?
- stationary
- walking
- running
- hiking
- cycling
- vehicle
- flight
- water activity
- unknown / mixed / uncertain

Your thoughts:
Yes. Definitely.

Updated conclusion:
- The proposed v1 visible class set is acceptable as a practical starting point.
- The main design goal should be reliability within this smaller visible vocabulary.

### 2. Hiking Boundary

Should hiking be treated as its own visible class in v1, or folded into walking until confidence is strong enough?

Your thoughts:
Folded into walking until we have confidence in our classification

Updated conclusion:
- Hiking should not be a default visible v1 class unless confidence is strong enough.
- In practice, that means walking remains the safer visible label and hiking can begin as a refinement or upgrade when evidence supports it.

### 3. Vehicle Refinement

Would it already be useful in v1 if the app internally tracked likely `driving`, `train`, `bus`, or `motorcycle`, even if the UI mostly showed `vehicle` unless confidence was very high?

Your thoughts:
Vehicle is good enough for now

Updated conclusion:
- Vehicle should remain the visible v1 class.
- Deeper subtype handling can be deferred rather than pursued internally from day one.
- This reduces complexity and keeps the classifier focused on the distinctions that matter most initially.

### 4. Water Refinement

Are you comfortable with `water activity` as the visible v1 class unless evidence for a narrower label is unusually strong?

Your thoughts:
Water activities, more than enough for now

Updated conclusion:
- Water activity is the right visible class for v1.
- Narrower water classifications should be treated as later refinements, not early commitments.

### 5. Sleep Timing

For purposes of the inference model, should sleep remain completely out of the initial movement classifier and be treated later as a separate passive-segment type?

Your thoughts:
Sure, I'm OK with treating it later as a passive segment type

Updated conclusion:
- Sleep should stay out of the first movement classifier.
- The model should allow it later, but it should not complicate the initial movement inference scope.

## Activity Inference Resting State

This branch now looks stable enough for a first-pass conclusion.

### Recommended v1 Visible Classes

- stationary
- walking
- running
- cycling
- vehicle
- flight
- water activity
- unknown / mixed / uncertain

### Classes Explicitly Deferred or Softened

- hiking: fold into walking unless confidence is strong
- driving/train/bus/motorcycle: defer and keep under vehicle
- swimming/rowing/sailing/speed boat: defer and keep under water activity
- sleep: treat later as a separate passive-segment type

### Product Implication

The classifier should aim to be conservative and honest:
- prefer a broad correct label over a narrow shaky one
- keep ambiguity first-class
- only promote a subtype to visible status when confidence justifies it

### Why This Is A Good v1 Scope

- it aligns with your priorities
- it avoids premature taxonomy complexity
- it keeps the review experience cleaner
- it preserves room to deepen the taxonomy later without redesigning the visible model too early

## Ready To Move On

The next natural branch is:
- rough data model shaping

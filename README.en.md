# Physics Study Handbook

[中文说明](README.md)

This repository contains an offline physics handbook in English and Chinese and a Chinese-language Godot desktop game, *Windseed Isles*. The handbook includes derivations and self-tests. The game puts physical models to work in freight loading, observation and flight.

## Getting started

- **Read offline.** Clone or download the repository and open the home page for your language in a browser. [English home](en/index.html) · [Chinese home](index.html)
- **Choose a topic.** Follow the prerequisites or look up a particular field or concept. [Learning path](en/learning-path.html) · [Taxonomy](en/taxonomy.html) · [Core concepts checklist](en/checklist.html)
- **Play Windseed Isles.** Import the game project in Godot 4.7.2 and press F5. In the opening shift, put a pump on a flatbed and see how its position changes the load on each axle. [Godot project](game/project.godot) · [Controls, headless tests and Windows builds (Chinese)](game/README.md)

## Course scope

The handbook grew from 18 broad categories and 38 introductory topics to **25 fields and a shared preparation track**. The taxonomy also lists directions for further study. Research training includes experiments, computation, reading papers and seeking feedback.

The fields are arranged for study and were checked against two catalogs on 2026-11-01. [APS PhySH](https://physh.org/) · [arXiv taxonomy](https://arxiv.org/category_taxonomy)

## What is actually delivered

- **319 lessons**: written in tiers — introductory lessons, mathematics preparation, undergraduate core, and advanced topic lessons; the per-field distribution is in the table below.
- **25 research replication trainings**: each comes with an implementation method, a check against known results, deliverable requirements, misinterpretation warnings, and extension questions.
- **369 direction entries** (names shared across fields may repeat; the total is the sum of the direction lists of the 26 fields, excluding the 4 methodology points at the top of the taxonomy): the taxonomy provides navigation and does not count each listed name as a finished tutorial.
- **19 interactive figures**; all lesson text, figures, and self-tests work offline.

## Current lesson catalog

| No. | Field | Type | Lessons | Research training |
|---|---|---|---:|---:|
| 00 | [Learning Preparation](en/00-learning-preparation/index.html) | Common foundations | 10 | — |
| 01 | [Classical Mechanics](en/01-classical-mechanics/index.html) | Foundational theory | 14 | 1 |
| 02 | [Vibrations, Waves and Acoustics](en/02-vibrations-waves-and-acoustics/index.html) | Foundations and specialty | 8 | 1 |
| 03 | [Thermodynamics and Statistical Physics](en/03-thermodynamics-and-statistical-physics/index.html) | Foundational theory | 16 | 1 |
| 04 | [Electromagnetism](en/04-electromagnetism/index.html) | Foundational theory | 15 | 1 |
| 05 | [Optics and Photonics](en/05-optics-and-photonics/index.html) | Specialty field | 11 | 1 |
| 06 | [Relativity and Gravitation](en/06-relativity-and-gravitation/index.html) | Foundational theory | 10 | 1 |
| 07 | [Quantum Mechanics](en/07-quantum-mechanics/index.html) | Foundational theory | 19 | 1 |
| 08 | [Atomic, Molecular and Optical Physics](en/08-atomic-molecular-and-optical-physics/index.html) | Research field | 12 | 1 |
| 09 | [Condensed Matter and Materials Physics](en/09-condensed-matter-and-materials-physics/index.html) | Research field | 15 | 1 |
| 10 | [Nuclear Physics](en/10-nuclear-physics/index.html) | Research field | 11 | 1 |
| 11 | [Particle Physics and Quantum Field Theory](en/11-particle-physics-and-quantum-field-theory/index.html) | Research field | 9 | 1 |
| 12 | [Plasma Physics](en/12-plasma-physics/index.html) | Research field | 13 | 1 |
| 13 | [Astrophysics and Cosmology](en/13-astrophysics-and-cosmology/index.html) | Research field | 16 | 1 |
| 14 | [Geophysics and Space Physics](en/14-geophysics-and-space-physics/index.html) | Interdisciplinary field | 13 | 1 |
| 15 | [Biophysics and Medical Physics](en/15-biophysics-and-medical-physics/index.html) | Interdisciplinary field | 15 | 1 |
| 16 | [Mathematical Physics](en/16-mathematical-physics/index.html) | Methods field | 12 | 1 |
| 17 | [Computational Physics](en/17-computational-physics/index.html) | Methods field | 17 | 1 |
| 18 | [Experimental Physics and Measurement](en/18-experimental-physics-and-measurement/index.html) | Methods field | 11 | 1 |
| 19 | [Fluid and Continuum Physics](en/19-fluid-and-continuum-physics/index.html) | Research field | 10 | 1 |
| 20 | [Nonlinear and Complex Systems](en/20-nonlinear-and-complex-systems/index.html) | Research field | 14 | 1 |
| 21 | [Quantum Information and Quantum Technologies](en/21-quantum-information-and-quantum-technologies/index.html) | Interdisciplinary field | 12 | 1 |
| 22 | [Chemical Physics and Molecular Reactions](en/22-chemical-physics-and-molecular-reactions/index.html) | Interdisciplinary field | 10 | 1 |
| 23 | [Accelerator and Beam Physics](en/23-accelerator-and-beam-physics/index.html) | Research field | 9 | 1 |
| 24 | [Applied Physics and Energy](en/24-applied-physics-and-energy/index.html) | Interdisciplinary field | 9 | 1 |
| 25 | [Foundations, History and Education of Physics](en/25-foundations-history-and-education-of-physics/index.html) | Context and reflection field | 8 | 1 |

## Learning order and completion criteria

1. High-school mathematics and units → calculus, complex numbers, linear algebra, and probability.
2. Mechanics → waves → heat and electromagnetism → optics → relativity and quantum.
3. Analytical mechanics, theoretical electromagnetism, thermodynamics and statistical physics, quantum mechanics, and mathematical methods form the undergraduate core; the full chapter exercises must be worked through.
4. Pick 1–2 specialty directions, go deep with graduate textbooks, then complete the local replication tasks.
5. Read papers, formulate questions independently, carry out research, and submit it to review — gradually building independent research ability.

Every lesson has explanations, derivations or worked examples, a self-test, answers, and its range of applicability. The new derivation lessons add standalone transfer exercises with solutions. Answering short questions correctly is not a sufficient condition for passing a stage.

## Work not yet done

- Long-form topic-by-topic courses, complete derivations, and full graded problem sets for every subfield in the taxonomy.
- Full-semester systematic syllabi for each of the four major theories, complete chapter exercises, and per-problem grading.
- Complete lecture notes for graduate topics, and the experimental or computational tools specific to each topic.
- Graded assessment, project review, and research feedback based on your actual submitted work.

These gaps are already marked on each field's home page and in the learning path; no auto-generated empty headings are used to stand in for finished textbook material.

## Maintenance and verification

- Content: DATA in `tools/build_course.py` holds the original lessons; `advanced_content.py`, `core_expansion.py`, and `expanded_fields.py` hold extension content. `extend_course.py` renders it. Edit the sources, then rebuild; validation rejects malformed rows, nonfinite answers, misplaced quizzes, and duplicate identities before generation.
- Rebuild: `python tools/build_course.py` or `python -m tools.build_course`. Importing the module does not write files. Lesson titles determine progress keys; consider migration when renaming a title.
- English edition: the [`en/`](en/index.html) tree is the English mirror of this handbook (English metadata: `en/course-manifest.json`). It is a hand-maintained static translation, not produced by the build script, so rebuilding does not overwrite it; when the Chinese sources change, update the corresponding `en/` pages (same filenames, directory names per the mapping in each `en/<chapter>/` slug), keep functional attributes (`data-answer`, `data-key`, `data-demo`, ids, classes) identical, and keep asset paths one level deeper (`../../assets/course.css`, `../assets/course.js` for chapter pages).
- Quick checks (Python 3.10+, no browser dependency): `python tools/check_course.py --structure-only` and `python -m unittest discover -s tests -v`.
- Browser dependencies: `pip install -r requirements.txt`, then `python -m playwright install chromium` (add `--with-deps` on Linux if needed).
- Verify: `python tools/check_course.py`. This is read-only by default and checks both editions, offline loading, grading boundaries, desktop/mobile layouts, dark-mode contrast, unavailable storage, and live cross-tab progress over local HTTP. Functional tests do not replace physics expert review.
- To update bilingual reports and screenshots, run `python tools/check_course.py --write-report`; optionally set `--report-date YYYY-MM-DD`. Reports are `verification/REPORT.md` and `verification/REPORT.en.md`.
- Local use: open `index.html` directly, or run `python -m http.server 8000 --bind 127.0.0.1` in the repository root and open the [local English home page](http://127.0.0.1:8000/en/). HTTP avoids browser differences in file-URL storage. Progress belongs to this browser and origin; it is not cloud synchronization.
- Grading: nonzero answers allow 2% relative error; zero answers must be exactly zero. Follow the question's units and rounding instructions. Numeric checks do not assess the written reasoning.
- Manifests: `course-manifest.json` and `en/course-manifest.json`. Review findings and sources: `REVIEW.md` and `REVIEW.en.md`.
- The pedagogy follows the [teach skill](https://github.com/mattpocock/skills/blob/main/skills/productivity/teach/SKILL.md)'s short lessons, retrieval practice, and spaced review; no third-party skill is installed globally.

## Cross-check against official classifications

All 51 leaf-level category codes of the arXiv physics group have been cross-checked (page snapshot of 2026-11-01); each has a local navigation assignment. See the [cross-reference table in the taxonomy](en/taxonomy.html) and the [machine-readable snapshot](classification-reference.json). This is a classification-coverage check against the named sources, not proof that every tutorial has been written.

## Detailed subfield list

The following is the local learning navigation; listing a name does not mean a tutorial for that topic has been completed. Cross-field topics may appear more than once, and the total number of entries is not a measure of subject coverage.

### 00 Learning Preparation

Units and dimensions; vectors and graphs; algebra, trigonometry, and calculus; models and errors; scientific notation; significant figures; systems of units; scalars and vectors; complex numbers; calculus; probability; linear algebra.

### 01 Classical Mechanics

Kinematics; Newtonian mechanics; rigid bodies and rotation; fluids and continuous media; analytical mechanics; nonlinear dynamics; systems of particles; impulse and collisions; central forces; the Kepler problem; constraints and generalized coordinates; Euler's equations for rigid bodies; Lagrangian mechanics; Hamiltonian mechanics; canonical transformations; classical fields; elasticity.

### 02 Vibrations, Waves and Acoustics

Simple harmonic motion; damping and resonance; mechanical waves; acoustics; nonlinear waves; forced oscillation; beats and normal modes; the wave equation; dispersion; group velocity; sound radiation; ultrasound; phonons; shock waves; solitary waves; acoustic metamaterials.

### 03 Thermodynamics and Statistical Physics

Laws of thermodynamics; kinetic theory of gases; statistical ensembles; phase transitions; nonequilibrium statistical mechanics; heat engines and refrigeration; chemical potential; Maxwell relations; the Boltzmann distribution; Fermi gas; Bose gas; critical phenomena; renormalization group; the Boltzmann equation; transport theory; stochastic processes; stochastic thermodynamics.

### 04 Electromagnetism

Electrostatic fields; circuits; magnetic fields; electromagnetic induction; Maxwell's theory; electromagnetic waves; boundary-value problems; multipole expansion; dielectrics; magnetic media; electromagnetic potentials and gauges; radiation; antennas; waveguides; electromagnetic response of plasmas; relativistic electrodynamics.

### 05 Optics and Photonics

Geometric optics; interference and diffraction; polarization; lasers; nonlinear and quantum optics; Fourier optics; imaging and aberrations; coherence theory; optical fibers; integrated photonics; ultrafast optics; nanophotonics; near-field optics; laser spectroscopy; holography; optomechanics; quantum optics.

### 06 Relativity and Gravitation

Special relativity; relativistic dynamics; general relativity; gravitational waves; four-vectors; relativistic collisions; the equivalence principle; differential geometry; Schwarzschild spacetime; rotating black holes; gravitational lensing; numerical relativity; gravitational experiments; gravitational-wave detection; candidate theories of quantum gravity.

### 07 Quantum Mechanics

Wave functions; measurement and operators; potential wells and tunneling; angular momentum and spin; many-body systems and quantum information; the Schrödinger equation; harmonic oscillator; the hydrogen atom; density matrix; angular-momentum coupling; identical particles; variational method; perturbation theory; scattering theory; path integrals; open quantum systems; quantum measurement theory.

### 08 Atomic, Molecular and Optical Physics

Atomic structure; molecular spectroscopy; atom–light interactions; cold atoms; precision spectroscopy; atomic collisions; hyperfine structure; molecular rotation; molecular vibration; selection rules; laser cooling; Bose–Einstein condensation; optical lattices; Rydberg atoms; atomic clocks; strong-field atomic physics; clusters.

### 09 Condensed Matter and Materials Physics

Crystals; energy bands and semiconductors; magnetism; superconductivity; soft matter; topological states of matter; lattices and reciprocal lattices; phonons; electron transport; semiconductors; magnetic order; strong correlations; superconductivity and superfluidity; quantum Hall effect; topological materials; low-dimensional materials; disorder and localization; liquid crystals; glass; granular matter; active condensed matter.

### 10 Nuclear Physics

Nuclear structure; radioactive decay; nuclear reactions; fission and fusion; nuclear astrophysics; nuclear shell model; collective model; alpha / beta / gamma decay; nuclear reaction cross sections; nuclear fission; nuclear fusion; heavy ions; nuclear matter equation of state; exotic nuclei; nucleosynthesis; probes of nuclear structure.

### 11 Particle Physics and Quantum Field Theory

The Standard Model; scattering; symmetries; quantum fields; neutrinos; beyond the Standard Model; quantum electrodynamics; quantum chromodynamics; electroweak theory; the Higgs mechanism; flavor physics; collider phenomenology; lattice field theory; effective field theory; gauge theories; renormalization; symmetry and anomalies; dark-matter candidates; string theory and quantum-gravity candidates.

### 12 Plasma Physics

Debye shielding; plasma waves; magnetohydrodynamics; magnetic confinement; space plasma; kinetics; instabilities; magnetic reconnection; inertial confinement; low-temperature plasma; dusty plasma; strongly coupled plasma; high-energy-density physics; plasma diagnostics.

### 13 Astrophysics and Cosmology

Stars; galaxies; compact objects; cosmology; the cosmic background and structure formation; solar physics; stellar structure and evolution; exoplanets; the interstellar medium; galactic dynamics; galaxy formation; high-energy sources; compact stars; black holes; the cosmic microwave background; large-scale structure; dark-matter observations; dark energy; the early universe; multi-messenger astronomy.

### 14 Geophysics and Space Physics

Seismology; geomagnetism; Earth's interior; atmospheric and ocean physics; the magnetosphere and solar–terrestrial relations; gravimetry; geothermal physics; mineral physics; planetary interiors; atmospheric physics; ocean physics; climate physics; the ionosphere; the magnetosphere; the solar wind; space weather; cosmic-ray propagation.

### 15 Biophysics and Medical Physics

Diffusion and molecular motors; membranes and neural electrical signaling; biomechanics; medical imaging; radiation physics; biomolecules; protein folding; membrane physics; single-molecule mechanics; molecular motors; cell mechanics; neurobiophysics; population and ecological physics; X-ray imaging; magnetic resonance; ultrasound; image reconstruction; dosimetry.

### 16 Mathematical Physics

Differential equations; Fourier analysis; functions of a complex variable; tensors and geometry; symmetry and group theory; ordinary differential equations; partial differential equations; special functions; complex analysis; Green's functions; integral transforms; tensors; differential geometry; groups and representations; functional analysis; calculus of variations; topology; integrable systems; rigorous mathematical physics.

### 17 Computational Physics

Numerical integration; Monte Carlo; molecular dynamics; solving partial differential equations; data and inverse problems; numerical linear algebra; algorithms for ordinary differential equations; finite differences; finite elements; spectral methods; quantum many-body computation; inverse problems; scientific machine learning; high-performance computing; reproducible workflows.

### 18 Experimental Physics and Measurement

Instruments and calibration; error analysis; detection and signals; experimental design; data fitting; metrology and calibration; uncertainty; Bayesian inference; detectors; low-noise electronics; signal processing; vacuum technology; cryogenics; optical experiments; data acquisition; control systems; statistical tests.

### 19 Fluid and Continuum Physics

Hydrostatics; viscous flow; compressible flow; turbulence; elasticity and plasticity; multiphase flow and interfaces; microfluidics.

### 20 Nonlinear and Complex Systems

Dynamical systems; chaos; bifurcations; solitons and integrable systems; pattern formation; complex networks; self-organization and active systems.

### 21 Quantum Information and Quantum Technologies

Qubits; entanglement; quantum measurement; quantum communication; quantum computing; quantum error correction; quantum sensing.

### 22 Chemical Physics and Molecular Reactions

Electronic structure; potential energy surfaces; reaction dynamics; surfaces and interfaces; molecular collisions; ultrafast processes; clusters and nanoscale systems.

### 23 Accelerator and Beam Physics

Charged-particle optics; radio-frequency acceleration; beam emittance; collective effects; synchrotron radiation; free-electron lasers; advanced acceleration.

### 24 Applied Physics and Energy

Electronic devices; spintronics; nanotechnology; metamaterials; optoelectronics and photovoltaics; energy storage and thermal management; nuclear energy and fusion applications.

### 25 Foundations, History and Education of Physics

Foundations of quantum theory; spacetime and causality; history of physics; philosophy of science; physics education research; science communication; physics and society.

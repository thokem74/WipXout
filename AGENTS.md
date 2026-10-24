# AGENTS.md

## Project context

This project is an Android game built with Godot. Changes should favor clear,
maintainable game code and workflows that are easy for a developer learning
GDScript and game development to follow.

## GDScript style

- Follow the official [Godot GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html).
- Use descriptive names, consistent formatting, and the standard ordering of
  class members, signals, properties, methods, and callbacks.
- Keep methods and classes focused. Prefer simple, explicit code over clever or
  unnecessarily compact implementations.
- Use typed variables and return types where they improve readability and make
  the code easier to understand.

## Scenes and visible game objects

- Create visible objects in Godot scenes (`.tscn`) rather than constructing
  them from script whenever practical.
- Use scripts to control behavior, state, and interactions for scene nodes.
- Keep scene structure and node relationships visible in the editor so they
  are easy to inspect, modify, and learn from.
- Instantiate reusable scenes from scripts when needed, but keep the visual
  composition and default configuration in the scene itself.

## Readability and comments

- Write code that is easy to read and understand before optimizing it.
- Add helpful comments for non-obvious logic, gameplay rules, math, engine
  behavior, and important design decisions.
- Prefer comments that explain why something is done; use clear names and
  straightforward code to explain what it does.
- Keep comments accurate and update them when the associated code changes.
- Organize larger systems into small, understandable pieces with clear
  responsibilities.

## Android and gameplay considerations

- Design input and UI with touch screens and different Android resolutions in
  mind.
- Avoid unnecessary per-frame work and object creation, especially in gameplay
  code that runs on mobile devices.
- Test changes in the Godot editor and on an Android build when the change can
  affect touch input, rendering, performance, or device-specific behavior.

package main

import (
	"timelines/gui"
	"timelines/simulator"
)

func main() {
	sim := simulator.NewSimulator()
	sim.Step()
	gui := gui.NewGUI(sim)

	gui.Run()
}

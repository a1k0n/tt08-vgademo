package gui

import (
	"image"
	"sync"
	"time"
	"timelines/simulator"

	g "github.com/AllenDang/giu"
)

type GUI struct {
	w              *g.MasterWindow
	frame          int32
	verilator_rgba *image.RGBA
	running        bool
	simCond        *sync.Cond
}

func NewGUI(sim *simulator.Simulator) *GUI {
	gui := &GUI{}
	gui.w = g.NewMasterWindow("Timeline Editor", 1220+16, 960+100, 0)

	gui.verilator_rgba = &image.RGBA{
		Pix:    sim.GetFramebuffer(),
		Rect:   image.Rect(0, 0, 1220, 960),
		Stride: 1220 * 4,
	}

	gui.running = true
	gui.simCond = sync.NewCond(&sync.Mutex{})

	go func() {
		for {
			if !gui.running {
				gui.simCond.L.Lock()
				gui.simCond.Wait()
				gui.simCond.L.Unlock()
			}

			sim.Step()
			gui.UpdateTexture(sim, gui.frame+1)
			time.Sleep(time.Millisecond * 8)
		}
	}()
	return gui
}

func (gui *GUI) UpdateTexture(sim *simulator.Simulator, frame int32) {
	gui.verilator_rgba.Pix = sim.GetFramebuffer()
	gui.frame = frame
	// wake up the main thread
	g.Update()
}

func (gui *GUI) Run() {
	gui.w.Run(func() {
		g.SingleWindow().Layout(
			g.Row(
				g.Button("Start/Stop").OnClick(func() {
					gui.running = !gui.running
					if gui.running {
						gui.simCond.Signal()
					}
				}),
				g.Button("Step").OnClick(func() {
					gui.running = false
					gui.simCond.Signal()
				}),
				g.Button("Reset"),
			),
			g.Row(
				g.Label("Frame"),
				g.SliderInt(&gui.frame, 0, 60*60*3), // three minutes of frames
			),
			g.ImageWithRgba(gui.verilator_rgba).Size(1220, 960),
		)
	})
}

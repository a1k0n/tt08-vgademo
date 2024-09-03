//go:generate make -C ../verilator/vgademo

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
	sim            *simulator.Simulator
	verilator_rgba *image.RGBA
	running        bool
	simCond        *sync.Cond
}

func NewGUI(sim *simulator.Simulator) *GUI {
	gui := &GUI{
		sim: sim,
	}
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

			gui.frame = int32(sim.Step()) - 1
			gui.verilator_rgba.Pix = sim.GetFramebuffer()
			g.Update()
			time.Sleep(time.Millisecond * 8)
		}
	}()
	return gui
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
				g.SliderInt(&gui.frame, 0, 60*60*3).OnChange(
					func() {
						// override the frame number
						gui.running = false
						gui.sim.SetFrame(int(gui.frame))
						gui.simCond.Signal()
					},
				),
			),
			g.ImageWithRgba(gui.verilator_rgba).Size(1220, 960),
		)
	})
}

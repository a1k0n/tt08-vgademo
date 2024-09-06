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
	xpos           int32
	p3             int32
	p4             int32
	p5             int32
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
	update_params := func() {
		gui.sim.SetParams(int(gui.frame), int(gui.xpos), int(gui.p3), int(gui.p4), int(gui.p5))
		gui.simCond.Signal()
	}

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
				g.SliderInt(&gui.frame, 0, 1467*2).OnChange(
					func() {
						// override the frame number
						gui.running = false
						update_params()
					},
				),
			),
			g.Row(
				g.Label("XPos"),
				g.SliderInt(&gui.xpos, 0, 2048).OnChange(update_params),
			),
			g.Row(
				g.Label("p3"),
				g.SliderInt(&gui.p3, 0, 1024).OnChange(update_params),
			),
			g.Row(
				g.Label("p4"),
				g.SliderInt(&gui.p4, 0, 1024).OnChange(update_params),
			),
			g.Row(
				g.Label("p5"),
				g.SliderInt(&gui.p5, 0, 1024).OnChange(update_params),
			),
			g.ImageWithRgba(gui.verilator_rgba).Size(1220, 960),
		)
	})
}

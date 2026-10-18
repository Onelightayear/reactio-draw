package main

// Small Windows API layer: COM calls through vtables, HGLOBALs, GDI pictures.

import (
	"bytes"
	"image"
	"image/png"
	"syscall"
	"unsafe"

	"golang.org/x/sys/windows"
)

var (
	ole32    = windows.NewLazySystemDLL("ole32.dll")
	user32   = windows.NewLazySystemDLL("user32.dll")
	kernel32 = windows.NewLazySystemDLL("kernel32.dll")
	gdi32    = windows.NewLazySystemDLL("gdi32.dll")
	comdlg32 = windows.NewLazySystemDLL("comdlg32.dll")

	pOleInitialize                = ole32.NewProc("OleInitialize")
	pOleUninitialize              = ole32.NewProc("OleUninitialize")
	pCoRegisterClassObject        = ole32.NewProc("CoRegisterClassObject")
	pCoRevokeClassObject          = ole32.NewProc("CoRevokeClassObject")
	pCoDisconnectObject           = ole32.NewProc("CoDisconnectObject")
	pCreateOleAdviseHolder        = ole32.NewProc("CreateOleAdviseHolder")
	pCreateDataAdviseHolder       = ole32.NewProc("CreateDataAdviseHolder")
	pCreateILockBytesOnHGlobal    = ole32.NewProc("CreateILockBytesOnHGlobal")
	pStgCreateDocfileOnILockBytes = ole32.NewProc("StgCreateDocfileOnILockBytes")
	pWriteClassStg                = ole32.NewProc("WriteClassStg")
	pWriteFmtUserTypeStg          = ole32.NewProc("WriteFmtUserTypeStg")
	pCoTaskMemAlloc               = ole32.NewProc("CoTaskMemAlloc")

	pOpenClipboard              = user32.NewProc("OpenClipboard")
	pCloseClipboard             = user32.NewProc("CloseClipboard")
	pEmptyClipboard             = user32.NewProc("EmptyClipboard")
	pSetClipboardData           = user32.NewProc("SetClipboardData")
	pGetClipboardData           = user32.NewProc("GetClipboardData")
	pRegisterClipboardFormatW   = user32.NewProc("RegisterClipboardFormatW")
	pIsClipboardFormatAvailable = user32.NewProc("IsClipboardFormatAvailable")
	pShowWindow                 = user32.NewProc("ShowWindow")
	pIsIconic                   = user32.NewProc("IsIconic")
	pSetForegroundWindow        = user32.NewProc("SetForegroundWindow")
	pIsWindowVisible            = user32.NewProc("IsWindowVisible")
	pDestroyWindow              = user32.NewProc("DestroyWindow")
	pPostMessageW               = user32.NewProc("PostMessageW")
	pMessageBoxW                = user32.NewProc("MessageBoxW")
	pGetDC                      = user32.NewProc("GetDC")
	pReleaseDC                  = user32.NewProc("ReleaseDC")
	pLoadImageW                 = user32.NewProc("LoadImageW")
	pSendMessageW               = user32.NewProc("SendMessageW")

	pGlobalAlloc  = kernel32.NewProc("GlobalAlloc")
	pGlobalLock   = kernel32.NewProc("GlobalLock")
	pGlobalUnlock = kernel32.NewProc("GlobalUnlock")
	pGlobalSize   = kernel32.NewProc("GlobalSize")
	pGlobalFree   = kernel32.NewProc("GlobalFree")

	pCreateEnhMetaFileW = gdi32.NewProc("CreateEnhMetaFileW")
	pCloseEnhMetaFile   = gdi32.NewProc("CloseEnhMetaFile")
	pCreateMetaFileW    = gdi32.NewProc("CreateMetaFileW")
	pCloseMetaFile      = gdi32.NewProc("CloseMetaFile")
	pStretchDIBits      = gdi32.NewProc("StretchDIBits")
	pSetWindowExtEx     = gdi32.NewProc("SetWindowExtEx")
	pSetWindowOrgEx     = gdi32.NewProc("SetWindowOrgEx")
	pGetDeviceCaps      = gdi32.NewProc("GetDeviceCaps")
	pSetStretchBltMode  = gdi32.NewProc("SetStretchBltMode")
	pSetEnhMetaFileBits = gdi32.NewProc("SetEnhMetaFileBits")

	pGetSaveFileNameW = comdlg32.NewProc("GetSaveFileNameW")
	pGetOpenFileNameW = comdlg32.NewProc("GetOpenFileNameW")
)

const (
	S_OK                  = 0
	S_FALSE               = 1
	E_NOTIMPL             = 0x80004001
	E_NOINTERFACE         = 0x80004002
	E_POINTER             = 0x80004003
	E_FAIL                = 0x80004005
	E_OUTOFMEMORY         = 0x8007000E
	OLE_S_USEREG          = 0x00040000
	DV_E_FORMATETC        = 0x80040064
	CLASS_E_NOAGGREGATION = 0x80040110

	CF_METAFILEPICT = 3
	CF_DIB          = 8
	CF_ENHMETAFILE  = 14
	TYMED_HGLOBAL   = 1
	TYMED_ISTORAGE  = 8
	TYMED_MFPICT    = 32
	TYMED_ENHMF     = 64
)

// IIDs of the standard OLE interfaces (Windows SDK, oleidl.h / objidl.h)
var (
	IID_IUnknown        = windows.GUID{Data1: 0x00000000, Data4: [8]byte{0xC0, 0, 0, 0, 0, 0, 0, 0x46}}
	IID_IClassFactory   = windows.GUID{Data1: 0x00000001, Data4: [8]byte{0xC0, 0, 0, 0, 0, 0, 0, 0x46}}
	IID_IPersistStorage = windows.GUID{Data1: 0x0000010A, Data4: [8]byte{0xC0, 0, 0, 0, 0, 0, 0, 0x46}}
	IID_IPersist        = windows.GUID{Data1: 0x0000010C, Data4: [8]byte{0xC0, 0, 0, 0, 0, 0, 0, 0x46}}
	IID_IDataObject     = windows.GUID{Data1: 0x0000010E, Data4: [8]byte{0xC0, 0, 0, 0, 0, 0, 0, 0x46}}
	IID_IOleObject      = windows.GUID{Data1: 0x00000112, Data4: [8]byte{0xC0, 0, 0, 0, 0, 0, 0, 0x46}}
)

// the program's own class (a fresh GUID made for it)
var CLSID_RD = windows.GUID{Data1: 0x6b0a1c3e, Data2: 0x5f2d, Data3: 0x4c8b, Data4: [8]byte{0x9a, 0x41, 0x2e, 0x7d, 0x13, 0xb5, 0x60, 0xc9}}

const appName = "Reactio Draw"
const progID = "ReactioDraw.Drawing.1"
const userType = "Reactio Draw"

func u16(s string) *uint16 { p, _ := windows.UTF16PtrFromString(s); return p }

// comCall calls method idx of a COM interface pointer
func comCall(p uintptr, idx int, args ...uintptr) uintptr {
	vt := *(*uintptr)(unsafe.Pointer(p))
	fn := *(*uintptr)(unsafe.Pointer(vt + uintptr(idx)*unsafe.Sizeof(uintptr(0))))
	r, _, _ := syscall.SyscallN(fn, append([]uintptr{p}, args...)...)
	return r
}
func addRef(p uintptr) {
	if p != 0 {
		comCall(p, 1)
	}
}
func release(p uintptr) {
	if p != 0 {
		comCall(p, 2)
	}
}

func failed(hr uintptr) bool { return int32(uint32(hr)) < 0 }

func clipFormat(name string) uint32 {
	r, _, _ := pRegisterClipboardFormatW.Call(uintptr(unsafe.Pointer(u16(name))))
	return uint32(r)
}

// HGLOBALs
func globalOf(b []byte) uintptr {
	h, _, _ := pGlobalAlloc.Call(0x0002, uintptr(len(b))) // GMEM_MOVEABLE
	if h == 0 {
		return 0
	}
	p, _, _ := pGlobalLock.Call(h)
	if len(b) > 0 {
		copy(unsafe.Slice((*byte)(unsafe.Pointer(p)), len(b)), b)
	}
	pGlobalUnlock.Call(h)
	return h
}
func globalBytes(h uintptr) []byte {
	n, _, _ := pGlobalSize.Call(h)
	p, _, _ := pGlobalLock.Call(h)
	if p == 0 {
		return nil
	}
	out := make([]byte, n)
	copy(out, unsafe.Slice((*byte)(unsafe.Pointer(p)), n))
	pGlobalUnlock.Call(h)
	return out
}

// ---------- pictures ----------

// picture: the drawing as a DIB (24-bit, on white) plus its size in HIMETRIC
type picture struct {
	dib      []byte // BITMAPINFOHEADER + bits
	emfData  []byte // the vector picture made by the page (EMF), when there is one
	pw, ph   int    // pixels
	wHi, hHi int32  // HIMETRIC
}

func pictureOf(pngBytes []byte, wHi, hHi int32) *picture {
	var img image.Image
	if len(pngBytes) > 0 {
		img, _ = png.Decode(bytes.NewReader(pngBytes))
	}
	if img == nil {
		img = image.NewRGBA(image.Rect(0, 0, 1, 1))
		if wHi <= 0 {
			wHi, hHi = 100, 100
		}
	}
	b := img.Bounds()
	w, h := b.Dx(), b.Dy()
	stride := (w*3 + 3) &^ 3
	dib := make([]byte, 40+stride*h)
	le32 := func(o int, v uint32) {
		dib[o], dib[o+1], dib[o+2], dib[o+3] = byte(v), byte(v>>8), byte(v>>16), byte(v>>24)
	}
	le32(0, 40)
	le32(4, uint32(w))
	le32(8, uint32(h)) // bottom-up
	dib[12], dib[14] = 1, 24
	le32(20, uint32(stride*h))
	le32(24, 11811) // 300 dpi
	le32(28, 11811)
	for y := 0; y < h; y++ {
		row := 40 + (h-1-y)*stride
		for x := 0; x < w; x++ {
			r, g, bl, a := img.At(b.Min.X+x, b.Min.Y+y).RGBA() // premultiplied, 16 bit
			k := 0xffff - a
			dib[row+x*3] = byte((bl + k) >> 8)
			dib[row+x*3+1] = byte((g + k) >> 8)
			dib[row+x*3+2] = byte((r + k) >> 8)
		}
	}
	if wHi <= 0 || hHi <= 0 {
		wHi, hHi = int32(w*2540/300), int32(h*2540/300)
	}
	return &picture{dib: dib, pw: w, ph: h, wHi: wHi, hHi: hHi}
}

func (p *picture) bits() (uintptr, uintptr) {
	return uintptr(unsafe.Pointer(&p.dib[40])), uintptr(unsafe.Pointer(&p.dib[0]))
}

// EMF with the picture stretched over the frame
func (p *picture) emf() uintptr {
	if len(p.emfData) > 0 {
		h, _, _ := pSetEnhMetaFileBits.Call(uintptr(len(p.emfData)), uintptr(unsafe.Pointer(&p.emfData[0])))
		if h != 0 {
			return h
		}
	}
	ref, _, _ := pGetDC.Call(0)
	defer pReleaseDC.Call(0, ref)
	hs, _, _ := pGetDeviceCaps.Call(ref, 4)  // HORZSIZE mm
	hr, _, _ := pGetDeviceCaps.Call(ref, 8)  // HORZRES px
	vs, _, _ := pGetDeviceCaps.Call(ref, 6)  // VERTSIZE
	vr, _, _ := pGetDeviceCaps.Call(ref, 10) // VERTRES
	rect := [4]int32{0, 0, p.wHi, p.hHi}
	dc, _, _ := pCreateEnhMetaFileW.Call(ref, 0, uintptr(unsafe.Pointer(&rect)), 0)
	if dc == 0 {
		return 0
	}
	pxW, pxH := int(p.wHi), int(p.hHi)
	if hs > 0 && vs > 0 {
		pxW = int(int64(p.wHi) * int64(hr) / (int64(hs) * 100))
		pxH = int(int64(p.hHi) * int64(vr) / (int64(vs) * 100))
	}
	pSetStretchBltMode.Call(dc, 4) // HALFTONE
	bits, bmi := p.bits()
	pStretchDIBits.Call(dc, 0, 0, uintptr(pxW), uintptr(pxH), 0, 0, uintptr(p.pw), uintptr(p.ph), bits, bmi, 0, 0x00CC0020)
	h, _, _ := pCloseEnhMetaFile.Call(dc)
	return h
}

// METAFILEPICT (Windows metafile, anisotropic) in an HGLOBAL
func (p *picture) mfpict() uintptr {
	dc, _, _ := pCreateMetaFileW.Call(0)
	if dc == 0 {
		return 0
	}
	pSetWindowOrgEx.Call(dc, 0, 0, 0)
	pSetWindowExtEx.Call(dc, uintptr(p.pw), uintptr(p.ph), 0)
	bits, bmi := p.bits()
	pStretchDIBits.Call(dc, 0, 0, uintptr(p.pw), uintptr(p.ph), 0, 0, uintptr(p.pw), uintptr(p.ph), bits, bmi, 0, 0x00CC0020)
	hmf, _, _ := pCloseMetaFile.Call(dc)
	type metafilepict struct {
		mm, xExt, yExt int32
		hMF            uintptr
	}
	mp := metafilepict{8, p.wHi, p.hHi, hmf} // MM_ANISOTROPIC
	b := unsafe.Slice((*byte)(unsafe.Pointer(&mp)), unsafe.Sizeof(mp))
	return globalOf(b)
}

func messageBox(text, title string) {
	pMessageBoxW.Call(0, uintptr(unsafe.Pointer(u16(text))), uintptr(unsafe.Pointer(u16(title))), 0x40)
}

(() => {
    if (location.origin !== "https://chatgpt.com") return;

    const reducedMotion = matchMedia("(prefers-reduced-motion: reduce)");
    const wheelSteps = new WeakMap();

    window.addEventListener("wheel", event => {
        if (!event.cancelable || event.ctrlKey || event.shiftKey || event.metaKey
                || Math.abs(event.deltaY) <= Math.abs(event.deltaX)) return;

        const target = event.target;
        if (!(target instanceof Element) || !target.closest("main")
                || target.closest("textarea, input, select, [contenteditable=true], [role=dialog]")) return;

        // Select the nearest scrollable under the pointer, including nested
        // code blocks. Let Chromium handle controls and other page regions.
        for (let node = target; node && node !== document.body; node = node.parentElement) {
            const limit = node.scrollHeight - node.clientHeight;
            if (limit < 1) continue;
            const style = getComputedStyle(node);
            if (!["auto", "scroll", "overlay"].includes(style.overflowY)) continue;
            const canScroll = event.deltaY < 0 ? node.scrollTop > 0 : node.scrollTop < limit - 0.5;
            if (canScroll) {
                const unit = event.deltaMode === WheelEvent.DOM_DELTA_PAGE ? node.clientHeight
                        : event.deltaMode === WheelEvent.DOM_DELTA_LINE ? (parseFloat(style.lineHeight) || 16) : 1;
                event.preventDefault();
                // Qt reports mouse-wheel notches in multiples of 60 CSS pixels.
                // Leave finer pixel deltas in sync with the touchpad.
                const stepped = event.deltaMode !== WheelEvent.DOM_DELTA_PIXEL
                        || Math.abs(event.deltaY) % 60 === 0;
                const delta = event.deltaY * unit;
                if (stepped && !reducedMotion.matches) {
                    const previousStep = wheelSteps.get(node);
                    const continuing = previousStep?.sign === Math.sign(delta)
                            && event.timeStamp - previousStep.time < 180;
                    const from = continuing ? previousStep.top : node.scrollTop;
                    const top = Math.max(0, Math.min(limit, from + delta));
                    node.scrollTo({ top, behavior: "smooth" });
                    wheelSteps.set(node, { top, sign: Math.sign(delta), time: event.timeStamp });
                } else {
                    wheelSteps.delete(node);
                    node.scrollBy({ top: delta, behavior: "instant" });
                }
                return;
            }
            if (style.overscrollBehaviorY !== "auto") return;
        }
    }, { capture: true, passive: false });
})();

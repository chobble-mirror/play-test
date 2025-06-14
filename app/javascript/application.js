// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails";

// Decimal field enhancement (self-contained)
(function() {
  function formatNumberValue(value) {
    if (value === '' || value === null || value === undefined) return value;
    const numValue = parseFloat(value);
    if (isNaN(numValue)) return value;
    return numValue.toString(); // Automatically removes trailing zeros
  }
  
  function initializeDecimalFields() {
    // Handle both decimal inputs and regular number inputs
    const numberInputs = document.querySelectorAll('.decimal-input, input[type="number"]');
    
    numberInputs.forEach(function(input) {
      // Skip if already initialized
      if (input.dataset.decimalInitialized) return;
      input.dataset.decimalInitialized = 'true';
      
      // Format initial value on load to remove trailing zeros
      if (input.value) {
        input.value = formatNumberValue(input.value);
      }
      
      // Format and trim trailing zeros on blur
      input.addEventListener('blur', function() {
        let value = this.value.trim();
        if (value === '') return;
        
        const numValue = parseFloat(value);
        if (!isNaN(numValue)) {
          // Convert to string to remove trailing zeros
          this.value = numValue.toString();
        }
      });
      
      // Clean input as user types (for decimal inputs only)
      if (input.classList.contains('decimal-input')) {
        input.addEventListener('input', function() {
          const value = this.value;
          const min = parseFloat(this.dataset.min);
          const max = parseFloat(this.dataset.max);
          
          // Remove invalid characters (keep digits, one dot, one minus at start)
          let cleaned = value.replace(/[^0-9.-]/g, '');
          
          // Handle minus sign (only at start)
          const minusCount = (cleaned.match(/-/g) || []).length;
          if (minusCount > 1) {
            cleaned = (cleaned.charAt(0) === '-' ? '-' : '') + cleaned.replace(/-/g, '');
          } else if (cleaned.includes('-') && cleaned.charAt(0) !== '-') {
            cleaned = cleaned.replace(/-/g, '');
          }
          
          // Handle decimal point (only one allowed)
          const dotCount = (cleaned.match(/\./g) || []).length;
          if (dotCount > 1) {
            const firstDotIndex = cleaned.indexOf('.');
            cleaned = cleaned.substring(0, firstDotIndex + 1) + 
                     cleaned.substring(firstDotIndex + 1).replace(/\./g, '');
          }
          
          this.value = cleaned;
          
          // Validate range if specified
          const numValue = parseFloat(cleaned);
          if (!isNaN(numValue)) {
            if (!isNaN(min) && numValue < min) {
              this.setCustomValidity(`Value must be at least ${min}`);
            } else if (!isNaN(max) && numValue > max) {
              this.setCustomValidity(`Value must be at most ${max}`);
            } else {
              this.setCustomValidity('');
            }
          } else if (cleaned !== '' && cleaned !== '-') {
            this.setCustomValidity('Please enter a valid number');
          } else {
            this.setCustomValidity('');
          }
        });
      }
    });
  }
  
  // Initialize on page load
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initializeDecimalFields);
  } else {
    initializeDecimalFields();
  }
  
  // Re-initialize after Turbo navigations
  document.addEventListener('turbo:load', initializeDecimalFields);
  document.addEventListener('turbo:frame-load', initializeDecimalFields);
})();

// Number input sanitization function
function sanitizeNumberInput(input) {
  const originalValue = input.value;

  if (originalValue === "") return; // Don't process empty values

  // Strip all non-numeric characters except decimal points and minus signs
  let sanitized = originalValue.replace(/[^0-9.-]/g, "");

  // Handle multiple minus signs - keep only first one if at beginning
  const isNegative = sanitized.startsWith("-");
  sanitized = sanitized.replace(/-/g, "");
  if (isNegative) sanitized = "-" + sanitized;

  // Handle multiple decimal points - keep only the first one
  const decimalParts = sanitized.split(".");
  if (decimalParts.length > 2) {
    sanitized = decimalParts[0] + "." + decimalParts.slice(1).join("");
  }

  // Update the input if the value changed
  if (originalValue !== sanitized) {
    input.value = sanitized;

    // Add visual feedback
    input.style.borderColor = "#8b5cf6";
    input.style.outline = "2px solid rgba(139, 92, 246, 0.5)";

    // Remove visual feedback after a short delay
    setTimeout(() => {
      input.style.borderColor = "";
      input.style.outline = "";
    }, 1000);

    return true; // Indicate that sanitization occurred
  }

  return false; // No sanitization needed
}

const DirtyForms = {
  indicator: null,
  form: null,
  initialState: null,

  init() {
    this.createIndicator();
    document
      .querySelectorAll("form")
      .forEach((form) => this.setupTracking(form));
  },

  createIndicator() {
    if (this.indicator) return;
    this.indicator = document.createElement("div");
    this.indicator.id = "dirty-form-indicator";
    this.indicator.innerHTML =
      '<div class="dirty-form-content"><span>Unsaved changes</span><button>Save</button></div>';
    this.indicator.style.display = "none";
    document.body.appendChild(this.indicator);
    this.indicator.querySelector("button").onclick = () =>
      this.form?.requestSubmit();
  },

  captureState(form) {
    const data = new FormData(form);
    const state = {};
    for (let [key, value] of data.entries()) state[key] = value;
    return JSON.stringify(state);
  },

  isDirty(form) {
    return this.initialState && this.captureState(form) !== this.initialState;
  },

  show() {
    if (this.indicator) this.indicator.style.display = "block";
  },

  hide() {
    if (this.indicator) this.indicator.style.display = "none";
  },

  setupTracking(form) {
    if (!form.querySelector("#form_save_message")) return;
    this.form = form;
    this.initialState = this.captureState(form);
    ["input", "change"].forEach((event) => {
      form.addEventListener(event, () =>
        this.isDirty(form) ? this.show() : this.hide(),
      );
    });
    form.addEventListener("submit", () => this.hide());
  },
};

document.addEventListener("turbo:load", function () {
  DirtyForms.init();
  const forms = document.querySelectorAll("form");

  forms.forEach((form) => {
    // Sanitize number inputs on change
    form.addEventListener("input", function (e) {
      if (e.target.type === "number") {
        sanitizeNumberInput(e.target);
      }
    });

    form.addEventListener("change", function (e) {
      if (e.target.type === "number") {
        sanitizeNumberInput(e.target);
      }
    });
  });

  // Handle comment field toggles
  document.addEventListener("change", function (e) {
    if (e.target.hasAttribute("data-comment-toggle")) {
      const textareaId = e.target.getAttribute("data-comment-toggle");
      const containerId = e.target.getAttribute("data-comment-container");
      const textarea = document.getElementById(textareaId);
      const container = document.getElementById(containerId);

      if (e.target.checked) {
        container.style.display = "block";
        textarea.focus();
      } else {
        container.style.display = "none";
        // Clear the comment when hiding
        textarea.value = "";
      }
    }
  });

  // Handle unit selection in inspection form
  const unitSelect = document.querySelector(
    'select[name="inspection[unit_id]"]',
  );
  if (unitSelect) {
    // Handle changes to show unit details
    unitSelect.addEventListener("change", function () {
      const selectedUnitId = this.value;

      if (selectedUnitId) {
        // Trigger form refresh to show unit details
        // This could be enhanced with AJAX to avoid page refresh
        const form = this.closest("form");
        const currentUrl = new URL(window.location);
        currentUrl.searchParams.set("unit_id", selectedUnitId);
        window.location.href = currentUrl.toString();
      }
    });
  }

  // Share functionality
  const shareButtons = document.querySelectorAll("[data-share-url]");
  shareButtons.forEach((button) => {
    button.addEventListener("click", async function (e) {
      e.preventDefault();
      const url = this.getAttribute("data-share-url");
      const title = this.getAttribute("data-share-title") || document.title;

      // Check if Web Share API is available (mobile)
      if (navigator.share) {
        try {
          await navigator.share({
            title: title,
            url: url,
          });
        } catch (err) {
          console.log("Share cancelled or failed", err);
        }
      } else {
        // Fallback to clipboard copy (desktop)
        try {
          await navigator.clipboard.writeText(url);

          // Show feedback
          const originalText = this.textContent;
          this.textContent = this.getAttribute("data-copied-text") || "Copied!";
          this.style.color = "#16a34a"; // green color

          setTimeout(() => {
            this.textContent = originalText;
            this.style.color = "";
          }, 2000);
        } catch (err) {
          console.error("Failed to copy URL", err);
          // Fallback for older browsers
          const textArea = document.createElement("textarea");
          textArea.value = url;
          textArea.style.position = "fixed";
          textArea.style.left = "-999999px";
          document.body.appendChild(textArea);
          textArea.select();
          try {
            document.execCommand("copy");
            // Show feedback
            const originalText = this.textContent;
            this.textContent =
              this.getAttribute("data-copied-text") || "Copied!";
            this.style.color = "#16a34a";

            setTimeout(() => {
              this.textContent = originalText;
              this.style.color = "";
            }, 2000);
          } catch (err) {
            console.error("Fallback copy failed", err);
          }
          document.body.removeChild(textArea);
        }
      }
    });
  });
});

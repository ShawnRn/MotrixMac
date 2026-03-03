/*! For license information please see theme.js.LICENSE.txt */
(()=>{"use strict";var r={5:(r,e,t)=>{t.d(e,{l:()=>n});var o=t(2405);function n(r,e){for(var t="",n=(0,o.FK)(r),a=0;a<n;a++)t+=e(r[a],a,r,e)||"";return t}},426:(r,e,t)=>{t(7228),t(2405),t(952),t(5)},952:(r,e,t)=>{t.d(e,{C:()=>a});var o=1,n=1;function a(r,e,t){return function(r,e,t,a,i,c){return{value:r,root:e,parent:t,type:a,props:i,children:c,line:o,column:n,length:0,return:""}}(r,e.root,e.parent,t,e.props,e.children)}},1664:r=>{var e=Object.getOwnPropertySymbols,t=Object.prototype.hasOwnProperty,o=Object.prototype.propertyIsEnumerable;r.exports=function(){try{if(!Object.assign)return!1;var r=new String("abc");if(r[5]="de","5"===Object.getOwnPropertyNames(r)[0])return!1;for(var e={},t=0;t<10;t++)e["_"+String.fromCharCode(t)]=t;if("0123456789"!==Object.getOwnPropertyNames(e).map(function(r){return e[r]}).join(""))return!1;var o={};return"abcdefghijklmnopqrst".split("").forEach(function(r){o[r]=r}),"abcdefghijklmnopqrst"===Object.keys(Object.assign({},o)).join("")}catch(r){return!1}}()?Object.assign:function(r,n){for(var a,i,c=function(r){if(null==r)throw new TypeError("Object.assign cannot be called with null or undefined");return Object(r)}(r),f=1;f<arguments.length;f++){for(var s in a=Object(arguments[f]))t.call(a,s)&&(c[s]=a[s]);if(e){i=e(a);for(var l=0;l<i.length;l++)o.call(a,i[l])&&(c[i[l]]=a[i[l]])}}return c}},1785:(r,e,t)=>{t.d(e,{AH:()=>n}),t(3696),t(426),t(8486);var o=t(3807);function n(){for(var r=arguments.length,e=new Array(r),t=0;t<r;t++)e[t]=arguments[t];return(0,o.J)(e)}},2332:(r,e)=>{var t="function"==typeof Symbol&&Symbol.for,o=t?Symbol.for("react.element"):60103,n=t?Symbol.for("react.portal"):60106,a=t?Symbol.for("react.fragment"):60107,i=t?Symbol.for("react.strict_mode"):60108,c=t?Symbol.for("react.profiler"):60114,f=t?Symbol.for("react.provider"):60109,s=t?Symbol.for("react.context"):60110,l=t?Symbol.for("react.async_mode"):60111,u=t?Symbol.for("react.concurrent_mode"):60111,p=t?Symbol.for("react.forward_ref"):60112,d=t?Symbol.for("react.suspense"):60113,y=t?Symbol.for("react.suspense_list"):60120,m=t?Symbol.for("react.memo"):60115,b=t?Symbol.for("react.lazy"):60116,g=t?Symbol.for("react.block"):60121,h=t?Symbol.for("react.fundamental"):60117,v=t?Symbol.for("react.responder"):60118,S=t?Symbol.for("react.scope"):60119;function x(r){if("object"==typeof r&&null!==r){var e=r.$$typeof;switch(e){case o:switch(r=r.type){case l:case u:case a:case c:case i:case d:return r;default:switch(r=r&&r.$$typeof){case s:case p:case b:case m:case f:return r;default:return e}}case n:return e}}}function w(r){return x(r)===u}e.AsyncMode=l,e.ConcurrentMode=u,e.ContextConsumer=s,e.ContextProvider=f,e.Element=o,e.ForwardRef=p,e.Fragment=a,e.Lazy=b,e.Memo=m,e.Portal=n,e.Profiler=c,e.StrictMode=i,e.Suspense=d,e.isAsyncMode=function(r){return w(r)||x(r)===l},e.isConcurrentMode=w,e.isContextConsumer=function(r){return x(r)===s},e.isContextProvider=function(r){return x(r)===f},e.isElement=function(r){return"object"==typeof r&&null!==r&&r.$$typeof===o},e.isForwardRef=function(r){return x(r)===p},e.isFragment=function(r){return x(r)===a},e.isLazy=function(r){return x(r)===b},e.isMemo=function(r){return x(r)===m},e.isPortal=function(r){return x(r)===n},e.isProfiler=function(r){return x(r)===c},e.isStrictMode=function(r){return x(r)===i},e.isSuspense=function(r){return x(r)===d},e.isValidElementType=function(r){return"string"==typeof r||"function"==typeof r||r===a||r===u||r===c||r===i||r===d||r===y||"object"==typeof r&&null!==r&&(r.$$typeof===b||r.$$typeof===m||r.$$typeof===f||r.$$typeof===s||r.$$typeof===p||r.$$typeof===h||r.$$typeof===v||r.$$typeof===S||r.$$typeof===g)},e.typeOf=x},2405:(r,e,t)=>{function o(r,e){return(((e<<2^c(r,0))<<2^c(r,1))<<2^c(r,2))<<2^c(r,3)}function n(r,e){return(r=e.exec(r))?r[0]:r}function a(r,e,t){return r.replace(e,t)}function i(r,e){return r.indexOf(e)}function c(r,e){return 0|r.charCodeAt(e)}function f(r){return r.length}function s(r){return r.length}function l(r,e){return r.map(e).join("")}t.d(e,{FK:()=>s,HC:()=>a,K5:()=>i,YW:()=>n,b2:()=>f,kg:()=>l,tW:()=>o,wN:()=>c}),Math.abs,String.fromCharCode},3107:(r,e,t)=>{t.d(e,{A:()=>o});const o=function(r){var e=Object.create(null);return function(t){return void 0===e[t]&&(e[t]=r(t)),e[t]}}},3696:(r,e,t)=>{t(4403)},3807:(r,e,t)=>{t.d(e,{J:()=>m});const o=function(r){for(var e,t=0,o=0,n=r.length;n>=4;++o,n-=4)e=1540483477*(65535&(e=255&r.charCodeAt(o)|(255&r.charCodeAt(++o))<<8|(255&r.charCodeAt(++o))<<16|(255&r.charCodeAt(++o))<<24))+(59797*(e>>>16)<<16),t=1540483477*(65535&(e^=e>>>24))+(59797*(e>>>16)<<16)^1540483477*(65535&t)+(59797*(t>>>16)<<16);switch(n){case 3:t^=(255&r.charCodeAt(o+2))<<16;case 2:t^=(255&r.charCodeAt(o+1))<<8;case 1:t=1540483477*(65535&(t^=255&r.charCodeAt(o)))+(59797*(t>>>16)<<16)}return(((t=1540483477*(65535&(t^=t>>>13))+(59797*(t>>>16)<<16))^t>>>15)>>>0).toString(36)},n={animationIterationCount:1,borderImageOutset:1,borderImageSlice:1,borderImageWidth:1,boxFlex:1,boxFlexGroup:1,boxOrdinalGroup:1,columnCount:1,columns:1,flex:1,flexGrow:1,flexPositive:1,flexShrink:1,flexNegative:1,flexOrder:1,gridRow:1,gridRowEnd:1,gridRowSpan:1,gridRowStart:1,gridColumn:1,gridColumnEnd:1,gridColumnSpan:1,gridColumnStart:1,msGridRow:1,msGridRowSpan:1,msGridColumn:1,msGridColumnSpan:1,fontWeight:1,lineHeight:1,opacity:1,order:1,orphans:1,tabSize:1,widows:1,zIndex:1,zoom:1,WebkitLineClamp:1,fillOpacity:1,floodOpacity:1,stopOpacity:1,strokeDasharray:1,strokeDashoffset:1,strokeMiterlimit:1,strokeOpacity:1,strokeWidth:1};var a=t(3107),i=/[A-Z]|^ms/g,c=/_EMO_([^_]+?)_([^]*?)_EMO_/g,f=function(r){return 45===r.charCodeAt(1)},s=function(r){return null!=r&&"boolean"!=typeof r},l=(0,a.A)(function(r){return f(r)?r:r.replace(i,"-$&").toLowerCase()}),u=function(r,e){switch(r){case"animation":case"animationName":if("string"==typeof e)return e.replace(c,function(r,e,t){return d={name:e,styles:t,next:d},e})}return 1===n[r]||f(r)||"number"!=typeof e||0===e?e:e+"px"};function p(r,e,t){if(null==t)return"";if(void 0!==t.__emotion_styles)return t;switch(typeof t){case"boolean":return"";case"object":if(1===t.anim)return d={name:t.name,styles:t.styles,next:d},t.name;if(void 0!==t.styles){var o=t.next;if(void 0!==o)for(;void 0!==o;)d={name:o.name,styles:o.styles,next:d},o=o.next;return t.styles+";"}return function(r,e,t){var o="";if(Array.isArray(t))for(var n=0;n<t.length;n++)o+=p(r,e,t[n])+";";else for(var a in t){var i=t[a];if("object"!=typeof i)null!=e&&void 0!==e[i]?o+=a+"{"+e[i]+"}":s(i)&&(o+=l(a)+":"+u(a,i)+";");else if(!Array.isArray(i)||"string"!=typeof i[0]||null!=e&&void 0!==e[i[0]]){var c=p(r,e,i);switch(a){case"animation":case"animationName":o+=l(a)+":"+c+";";break;default:o+=a+"{"+c+"}"}}else for(var f=0;f<i.length;f++)s(i[f])&&(o+=l(a)+":"+u(a,i[f])+";")}return o}(r,e,t);case"function":if(void 0!==r){var n=d,a=t(r);return d=n,p(r,e,a)}}if(null==e)return t;var i=e[t];return void 0!==i?i:t}var d,y=/label:\s*([^\s;\n{]+)\s*(;|$)/g,m=function(r,e,t){if(1===r.length&&"object"==typeof r[0]&&null!==r[0]&&void 0!==r[0].styles)return r[0];var n=!0,a="";d=void 0;var i=r[0];null==i||void 0===i.raw?(n=!1,a+=p(t,e,i)):a+=i[0];for(var c=1;c<r.length;c++)a+=p(t,e,r[c]),n&&(a+=i[c]);y.lastIndex=0;for(var f,s="";null!==(f=y.exec(a));)s+="-"+f[1];return{name:o(a)+s,styles:a,next:d}}},4403:(r,e,t)=>{var o=t(1664);if("function"==typeof Symbol&&Symbol.for){var n=Symbol.for;n("react.element"),n("react.portal"),n("react.fragment"),n("react.strict_mode"),n("react.profiler"),n("react.provider"),n("react.context"),n("react.forward_ref"),n("react.suspense"),n("react.memo"),n("react.lazy")}"function"==typeof Symbol&&Symbol.iterator;function a(r){for(var e="https://reactjs.org/docs/error-decoder.html?invariant="+r,t=1;t<arguments.length;t++)e+="&args[]="+encodeURIComponent(arguments[t]);return"Minified React error #"+r+"; visit "+e+" for the full message or use the non-minified dev environment for full errors and additional helpful warnings."}var i={isMounted:function(){return!1},enqueueForceUpdate:function(){},enqueueReplaceState:function(){},enqueueSetState:function(){}},c={};function f(r,e,t){this.props=r,this.context=e,this.refs=c,this.updater=t||i}function s(){}function l(r,e,t){this.props=r,this.context=e,this.refs=c,this.updater=t||i}f.prototype.isReactComponent={},f.prototype.setState=function(r,e){if("object"!=typeof r&&"function"!=typeof r&&null!=r)throw Error(a(85));this.updater.enqueueSetState(this,r,e,"setState")},f.prototype.forceUpdate=function(r){this.updater.enqueueForceUpdate(this,r,"forceUpdate")},s.prototype=f.prototype;var u=l.prototype=new s;u.constructor=l,o(u,f.prototype),u.isPureReactComponent=!0;Object.prototype.hasOwnProperty},7228:(r,e,t)=>{t.d(e,{LU:()=>c,MS:()=>o,Sv:()=>f,XZ:()=>i,j:()=>a,vd:()=>n});var o="-ms-",n="-moz-",a="-webkit-",i="rule",c="decl",f="@keyframes"},8486:(r,e,t)=>{var o=t(9360),n={childContextTypes:!0,contextType:!0,contextTypes:!0,defaultProps:!0,displayName:!0,getDefaultProps:!0,getDerivedStateFromError:!0,getDerivedStateFromProps:!0,mixins:!0,propTypes:!0,type:!0},a={name:!0,length:!0,prototype:!0,caller:!0,callee:!0,arguments:!0,arity:!0},i={$$typeof:!0,compare:!0,defaultProps:!0,displayName:!0,propTypes:!0,type:!0},c={};function f(r){return o.isMemo(r)?i:c[r.$$typeof]||n}c[o.ForwardRef]={$$typeof:!0,render:!0,defaultProps:!0,displayName:!0,propTypes:!0},c[o.Memo]=i;var s=Object.defineProperty,l=Object.getOwnPropertyNames,u=Object.getOwnPropertySymbols,p=Object.getOwnPropertyDescriptor,d=Object.getPrototypeOf,y=Object.prototype;r.exports=function r(e,t,o){if("string"!=typeof t){if(y){var n=d(t);n&&n!==y&&r(e,n,o)}var i=l(t);u&&(i=i.concat(u(t)));for(var c=f(e),m=f(t),b=0;b<i.length;++b){var g=i[b];if(!(a[g]||o&&o[g]||m&&m[g]||c&&c[g])){var h=p(t,g);try{s(e,g,h)}catch(r){}}}}return e}},9360:(r,e,t)=>{r.exports=t(2332)}},e={};function t(o){var n=e[o];if(void 0!==n)return n.exports;var a=e[o]={exports:{}};return r[o](a,a.exports,t),a.exports}t.n=r=>{var e=r&&r.__esModule?()=>r.default:()=>r;return t.d(e,{a:e}),e},t.d=(r,e)=>{for(var o in e)t.o(e,o)&&!t.o(r,o)&&Object.defineProperty(r,o,{enumerable:!0,get:e[o]})},t.o=(r,e)=>Object.prototype.hasOwnProperty.call(r,e),t(1785).AH`
  :root {
    --primary-color: #007aff;
    --primary-color-dim: rgba(0, 122, 255, 0.15);
    --bg: #f2f2f7;
    --card-bg: rgba(255, 255, 255, 0.7);
    --text-primary: #000000;
    --text-secondary: #636366;
    --border-color: rgba(0, 0, 0, 0.1);
    --border-color-light: rgba(0, 0, 0, 0.05);
    --shadow-color: rgba(0, 0, 0, 0.08);
    --shadow-color-hover: rgba(0, 0, 0, 0.12);
    --input-bg: #ffffff;
    --success-color: #34c759;
    --error-color: #ff3b30;
  }

  @media (prefers-color-scheme: dark) {
    :root {
      --primary-color: #0a84ff;
      --primary-color-dim: rgba(10, 132, 255, 0.2);
      --bg: #000000;
      --card-bg: rgba(28, 28, 30, 0.7);
      --text-primary: #f5f5f7;
      --text-secondary: #98989d;
      --border-color: #38383a;
      --border-color-light: #2c2c2e;
      --shadow-color: rgba(0, 0, 0, 0.3);
      --shadow-color-hover: rgba(0, 0, 0, 0.5);
      --input-bg: rgba(255, 255, 255, 0.05);
    }
  }

  body {
    margin: 0;
    padding: 0;
    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Segoe UI',
      Roboto, Helvetica, Arial, sans-serif;
    background-color: var(--bg);
    color: var(--text-primary);
    line-height: 1.5;
    transition: background-color 0.3s ease;
  }

  * {
    box-sizing: border-box;
  }

  /* Force dark mode via attribute */
  [data-theme='dark'] {
    --primary-color: #0a84ff;
    --primary-color-dim: rgba(10, 132, 255, 0.2);
    --bg: #000000;
    --card-bg: rgba(28, 28, 30, 0.7);
    --text-primary: #f5f5f7;
    --text-secondary: #98989d;
    --border-color: #38383a;
    --border-color-light: #2c2c2e;
    --shadow-color: rgba(0, 0, 0, 0.3);
    --shadow-color-hover: rgba(0, 0, 0, 0.5);
    --input-bg: rgba(255, 255, 255, 0.05);
  }

  [data-theme='light'] {
    --primary-color: #007aff;
    --primary-color-dim: rgba(0, 122, 255, 0.2);
    --bg: #f5f5f7;
    --card-bg: rgba(255, 255, 255, 0.8);
    --text-primary: #1d1d1f;
    --text-secondary: #86868b;
    --border-color: #e5e5e5;
    --border-color-light: #f0f0f0;
    --shadow-color: rgba(0, 0, 0, 0.05);
    --shadow-color-hover: rgba(0, 0, 0, 0.1);
    --input-bg: #ffffff;
  }
`})();
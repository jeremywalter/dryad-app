import React from 'react';

const instructions = (props) => {
  return (
    <div>
      <p>
        You may upload data via two mechanisms: directly from your computer, or from a URL
        on an external server (e.g., Box, Dropbox, AWS, lab server). We do not recommend
        using Google Drive.
      </p>
      <p>
        We require that you include a README file to provide key information for understanding
        and using your data.  README files should be uploaded to the <em>Data</em> category below.
      </p>
      <p>
        Software and Supplemental Information can be uploaded for publication at <a href="https://zenodo.org" target="_blank">Zenodo</a>.
        You will have the opportunity to choose a separate license for your software on the
        review page.
      </p>
    </div>
    )
}

export default instructions;
